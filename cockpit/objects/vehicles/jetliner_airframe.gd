@tool
extends Node3D
class_name JetlinerAirframe
## A SWEPT-WING JET AIRLINER, DRAWN FROM A MEASURED TABLE: the builder the Boeing 737-800 (`Boeing737Airframe`) and the
## 747-400 (`Boeing747Airframe`) share. Each of those is a TABLE and nothing else -- the measured figures and where each
## came from -- and this is the drawing: a round-ish pressure fuselage lofted through the table's stations, a low swept
## wing with a kink and a winglet, podded engines on pylons, a conventional tail, and the gear.
##
## WHY ONE BUILDER FOR TWO AEROPLANES. A 737 and a 747 are the same drawing problem at two sizes: the same wing, the same
## pods, the same tail and the same gear sequence, and what makes each one itself is a table of numbers -- a 747's upper
## deck is its fuselage table's crown, not a separate part bolted on, and its four engines are four rows in the nacelle
## table. Two copies of this file would drift the first time a fix went into one of them.
##
## PRESENTATION ONLY. The native simulation owns the collision box, the mass, the seats and the flight. The table carries
## a DRAFT of the box the kind will get (`geometry`), and the frame is that box's: the origin at its centre, the ground at
## its bottom, the nose tip at its front face. Until the C++ shape is changed to match, the drawn aeroplane and the
## collided box are different sizes, and the airframe's suite says so rather than hiding it.
##
## THE FRAME: every figure in a table is `station` metres aft of the nose tip, `out` metres to starboard of the centreline
## and `high` metres over the ground with the gear down. `point(out, high, station)` puts one in the craft's frame.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT (the user's direction of 2026-09-17, with the E-2D Hawkeye as the
## reference; every count is at or below the Hawkeye's for the same kind of part):
## - the FUSELAGE: 16 facets a ring (the Hawkeye's 20), the upper lobe a quarter-circle of four facets a side and the lower
##   lobe four more, through the table's measured stations;
## - a NACELLE: 12 facets a ring (the Hawkeye's nacelle round is 20); a TYRE: 8;
## - a wing, tail or fin section: SIX points, as the F-16's and the F-35B's.
## Every face carries its own normal (`Plating`); nothing is smoothed.
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's colour
## is in its vertices (`lane/fleet`, Hawkeye).

## THE GEAR CYCLE AS SHARES OF ONE AMOUNT, 0 up and 1 down: the well doors open over the first fifth, the legs travel over
## the middle, and the doors shut again over the last fifth (`actuators_research.md` 3.5, the F-35B's shares).
const DOORS_OPEN_BY: float = 0.2
const DOORS_SHUT_FROM: float = 0.8
## How far a hinged surface turns at full travel. ESTIMATE, each a round figure inside the published ranges for Boeing
## jets: the flaps to 40 degrees (the 737's last detent is 40), the ailerons 20, the elevators 20, the rudder 25, the
## spoilers up 45, the well doors 85.
const FLAP_TRAVEL: float = deg_to_rad(40.0)
const AILERON_TRAVEL: float = deg_to_rad(20.0)
const ELEVATOR_TRAVEL: float = deg_to_rad(20.0)
const RUDDER_TRAVEL: float = deg_to_rad(25.0)
const SPOILER_TRAVEL: float = deg_to_rad(45.0)
const WELL_OPEN: float = deg_to_rad(85.0)
## Facets round a nacelle and a tyre.
const NACELLE_SIDES: int = 12
const WHEEL_SIDES: int = 8
## Small fittings stop drawing once the aeroplane is a few pixels high.
const DETAIL_RANGE: float = 1400.0
const DETAIL_HYSTERESIS: float = 140.0

var _t: Dictionary = {}
## THE CARGO RAMP'S AND THE UPPER CARGO DOOR'S SKIN, taken out of the fuselage's loft by `_fuselage` where the table has a
## `ramp` (the C-130's), and built into their own hinged parts by `_build_ramp`.
var _ramp_tools: Array = []
var _ramp: float = 0.0
## A SLIDING LEG's travel from down to stowed, by the leg's index in `_legs`; zero for a leg that swings.
var _slides: Array[Vector3] = []
var _leg_down: Array[Vector3] = []
var _half: Vector3 = Vector3.ONE
var _hinges: Dictionary = {}
var _legs: Array[Node3D] = []
var _stowed: Array[Quaternion] = []
var _gear: float = 1.0
var _flaps: float = 0.0
var _spoilers: float = 0.0
var _pitch: float = 0.0
var _roll: float = 0.0
var _yaw: float = 0.0


## THE TABLE, supplied by the aeroplane's own class. See `Boeing737Airframe.table`.
func table() -> Dictionary:
	return {}


## BUILT IN PLACE, after `new()`. The simulation's geometry is accepted and NOT used for the frame until the kind's box is
## the table's (`geometry_matches`): see the class note.
func dress(_native: Dictionary = {}) -> void:
	_t = table()
	name = String(_t["name"])
	_half = (_t["geometry"] as Dictionary)["extents"] as Vector3
	var paint: StandardMaterial3D = ShipHull.painted()
	paint.roughness = 0.45
	# THE SKIN SEEN FROM THE FLIGHT DECK: double-sided, or from inside the one closed solid the crew sees no aeroplane at
	# all (the Tomcat's and the F-16's station pictures, 2026-09-18).
	var inside: StandardMaterial3D = ShipHull.painted()
	inside.roughness = 0.45
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED
	# THE WINDSCREEN IS GLASS THE CREW SEES OUT THROUGH, drawn from both sides and half see-through, as the F-16's is.
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	glass.albedo_color = Color(1.0, 1.0, 1.0, 0.5)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.08
	glass.metallic = 0.3

	# ONE DRAW CALL A THING THAT DOES NOT MOVE ON ITS OWN: the cabin windows are in the fuselage's mesh, each winglet in its
	# wing's and each pylon in its engine's. `aircraft_fidelity` holds a craft's parts to 40 draw calls, and the first
	# build of the 747 had 53.
	var body := _tool()
	var screen := _tool()
	_ramp_tools = [_tool(), _tool()] if _t.has("ramp") else []
	_fuselage(body, screen)
	_cabin_windows(body)
	var fuselage := _add(self, "Fuselage", body, paint)
	fuselage.material_override = null
	fuselage.mesh = screen.commit(fuselage.mesh as ArrayMesh)
	fuselage.set_surface_override_material(0, inside)
	fuselage.set_surface_override_material(1, glass)
	# THE FAIRING STAYS A PART OF ITS OWN: it is a closed solid under the fuselage, and in the fuselage's mesh a ray fired
	# down from a seat over the wing would cross it and read the seat as outside (`modelling_here.md` section 6).
	if _t.has("fairing"):
		var fairing := _tool()
		_wing_to_body_fairing(fairing)
		_add(self, "WingToBodyFairing", fairing, paint)

	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var wing := _tool()
		_wing(wing, side)
		_winglet(wing, side)
		_add(self, "Wing" + named, wing, paint)
		_wing_surfaces(side, named, paint)
		var tailplane := _tool()
		_tailplane(tailplane, side)
		_add(self, "Tailplane" + named, tailplane, paint)
		_elevator(side, named, paint)
	var index: int = 0
	for nacelle in _t["nacelles"]:
		index += 1
		var pod := _tool()
		_nacelle(pod, nacelle as Dictionary)
		_pylon(pod, nacelle as Dictionary)
		_add(self, "Engine%d" % index, pod, paint)
	var fin := _tool()
	_fin(fin)
	_add(self, "Fin", fin, paint)
	_rudder(paint)
	_build_gear(paint)
	_build_ramp(paint)
	_extras(paint)
	set_gear(1.0)


## An aeroplane's own parts past the common ones: nothing on the 737.
func _extras(_paint: Material) -> void:
	pass


# ---- the frame ---------------------------------------------------------------------------------------------------------

## A POINT: `out` metres to starboard, `high` over the ground and `station` aft of the nose tip, in the craft's frame.
func point(out: float, high: float, station: float) -> Vector3:
	return Vector3(out, high - _half.y, station - _half.z)


## The box the table draws in, as the simulation's geometry dictionary: what the C++ shape must become.
func geometry() -> Dictionary:
	return (table()["geometry"] as Dictionary).duplicate(true)


## A HEIGHT OFF THE DRAWING, raised by the table's `raise`: the drawing's body sits under the published clearances by
## that much (see the aeroplane's table), so every height the drawing gives is lifted by it and the gear is lengthened to
## match. The ground is not raised.
func drawn(h: float) -> float:
	return h + float(_t.get("raise", 0.0))


# ---- the fuselage -------------------------------------------------------------------------------------------------------

## ONE COLUMN of the fuselage table at a station, interpolated: 1 the half-width, 2 the keel, 3 the crown (drawn heights).
func _column(s: float, column: int) -> float:
	var rows: Array = _t["fuselage"]
	if s <= float(rows[0][0]):
		return float(rows[0][column])
	for i in range(rows.size() - 1):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		if s <= float(b[0]):
			return lerpf(float(a[column]), float(b[column]), (s - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(rows[-1][column])


## THE HALF-RING at a station, from the crown down the starboard side to the keel, as (out, high) points.
## The upper lobe is a quarter-ellipse whose radius is the half-width, down to the shoulder; the lower lobe a quarter-ellipse
## from the shoulder to the keel. Where the section is shallower than it is wide (the nose and the tail cone), the shoulder
## sits at mid-height. Nine points, four facets a lobe.
##
## AN UPPER DECK (the table's `upper_deck`, the 747's) is a second, narrower lobe standing on the main one: a circle of
## `radius` (or `share` of the half-width, where that is less) whose top is the crown, over a main lobe whose own top is
## `main_depth` half-widths over the keel. The two meet at a WAIST, a crease the real hump has. Such a table's rings are ten
## points a half -- the crown, two points on the upper lobe, the waist, one on the main lobe and the shoulder, over the
## lower lobe's four -- at every station, so the loft's rings all match; where there is no hump the six upper points lie on
## the one quarter-circle.
func _half_ring(s: float) -> Array:
	var w: float = _column(s, 1)
	var keel: float = drawn(_column(s, 2))
	var crown: float = drawn(_column(s, 3))
	if not _t.has("upper_deck"):
		var shoulder: float = crown - minf(w, (crown - keel) * 0.5)
		var out: Array = []
		for k in range(5):
			var a: float = PI * 0.5 * float(k) / 4.0
			out.append(Vector2(w * sin(a), shoulder + (crown - shoulder) * cos(a)))
		for k in range(1, 5):
			var a: float = PI * 0.5 * float(k) / 4.0
			out.append(Vector2(w * cos(a), shoulder - (shoulder - keel) * sin(a)))
		return out
	var deck: Dictionary = _t["upper_deck"]
	var main_top: float = minf(crown, keel + float(deck["main_depth"]) * w)
	var mr: float = minf(w, (main_top - keel) * 0.5)
	var shoulder: float = main_top - mr
	var half: Array = []
	var ru: float = minf(float(deck["radius"]), float(deck["share"]) * w)
	var cu: float = crown - ru
	# THE WAIST: where the upper lobe's circle meets the main lobe's ellipse (half-width w, half-height mr).
	var waist := Vector2(-1.0, 0.0)
	if crown > main_top + 0.05:
		var lo: float = maxf(shoulder, cu)
		var hi: float = main_top
		var gap := func(y: float) -> float:
			var main_x: float = w * sqrt(maxf(0.0, 1.0 - pow((y - shoulder) / mr, 2.0)))
			var upper_x: float = sqrt(maxf(0.0, ru * ru - pow(y - cu, 2.0)))
			return main_x - upper_x
		if float(gap.call(lo)) > 0.0 and float(gap.call(hi)) < 0.0:
			for _i in range(40):
				var mid: float = (lo + hi) * 0.5
				if float(gap.call(mid)) > 0.0:
					lo = mid
				else:
					hi = mid
			var y: float = (lo + hi) * 0.5
			waist = Vector2(sqrt(maxf(0.0, ru * ru - pow(y - cu, 2.0))), y)
	if waist.x < 0.0:
		for k in range(6):
			var a: float = PI * 0.5 * float(k) / 5.0
			half.append(Vector2(w * sin(a), shoulder + (crown - shoulder) * cos(a)))
	else:
		var top_a: float = acos(clampf((waist.y - cu) / ru, -1.0, 1.0))
		half.append(Vector2(0.0, crown))
		for k in [1, 2]:
			var a: float = top_a * float(k) / 3.0
			half.append(Vector2(ru * sin(a), cu + ru * cos(a)))
		half.append(waist)
		var main_a: float = asin(clampf(waist.x / w, 0.0, 1.0))
		var mid_a: float = (main_a + PI * 0.5) * 0.5
		half.append(Vector2(w * sin(mid_a), shoulder + mr * cos(mid_a)))
		half.append(Vector2(w, shoulder))
	for k in range(1, 5):
		var a: float = PI * 0.5 * float(k) / 4.0
		half.append(Vector2(w * cos(a), shoulder - (shoulder - keel) * sin(a)))
	return half


## THE FULL RING round from the crown: starboard down to the keel and port back up.
func _ring(s: float) -> Array:
	var half: Array = _half_ring(s)
	var points: Array = []
	for i in range(half.size() - 1):
		points.append(point((half[i] as Vector2).x, (half[i] as Vector2).y, s))
	for i in range(half.size() - 1, 0, -1):
		points.append(point(-(half[i] as Vector2).x, (half[i] as Vector2).y, s))
	return points


## WHETHER A FUSELAGE FACET is flight-deck glass: its middle inside one of the table's windscreen panes, each
## [fore, aft, low, high, least out] in drawn heights.
func _glazed(out: float, high: float, s: float) -> bool:
	for pane in _t["windscreen"]:
		if s > float(pane[0]) and s < float(pane[1]) and high > drawn(float(pane[2])) and high < drawn(float(pane[3])) \
				and absf(out) > float(pane[4]):
			return true
	return false


## THE PAINT OF A FUSELAGE FACET: the livery's cheatline band between where it starts and stops (short of a tail cone
## whose rising keel would carry the band's heights onto its belly facets), the upper body, the belly.
func _body_tint(high: float, s: float = 1000.0) -> Color:
	var livery: Dictionary = _t["livery"]
	# A RADOME, where the livery names one: every facet ahead of its station.
	if livery.has("radome") and s < float((livery["radome"] as Vector2).x):
		return livery["radome_colour"]
	var band: Vector2 = livery["cheatline"]
	if high > drawn(band.x) and high < drawn(band.y) and s > float(livery.get("cheatline_from", 0.0)) \
			and s < float(livery.get("cheatline_to", 1000.0)):
		return livery["stripe"]
	return livery["top"] if high > drawn(float(livery["belly_below"])) else livery["belly"]


## THE FUSELAGE: 16 flat facets a ring through the table's stations, closed by a fan to the nose tip and one to the tail
## cone's tip. Facets inside a windscreen pane go into `screen`, the fuselage's second surface, so the skin round the crew
## is one closed solid (`tests/shell_room.gd`).
func _fuselage(tool: SurfaceTool, screen: SurfaceTool) -> void:
	var stations: Array = []
	for row in _t["fuselage"]:
		stations.append(float(row[0]))
	var rings: Array = []
	for s in stations:
		rings.append(_ring(float(s)))
	var n: int = (rings[0] as Array).size()
	for r in range(rings.size() - 1):
		var here: float = (float(stations[r]) + float(stations[r + 1])) * 0.5
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var mid_h: float = (drawn(_column(here, 2)) + drawn(_column(here, 3))) * 0.5
		var centre: Vector3 = point(0.0, mid_h, here)
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var out: Vector3 = Vector3(mid.x - centre.x, mid.y - centre.y, 0.0)
			var high: float = mid.y + _half.y
			# THE RAMP AND THE UPPER CARGO DOOR are the lower lobe's facets (the lower half of the ring, 4 facets a side)
			# between the ramp's hinge and the door's aft edge: into their own tools, and out of the fuselage.
			if not _ramp_tools.is_empty():
				var rp: Dictionary = _t["ramp"]
				var lower: bool = k >= n / 4 and k < n * 3 / 4
				if lower and here > float(rp["hinge"]) and here < float(rp["door_end"]):
					var into: SurfaceTool = _ramp_tools[0] if here < float(rp["end"]) else _ramp_tools[1]
					Plating.facing(into, quad, out, _body_tint(high, here))
					# AND ITS INSIDE, 3 cm in and the hold's colour, so an open ramp reads as a floor and a lowered door as
					# a door: a skin with no inner face is seen through from above.
					var inner: Array = []
					for c in quad:
						inner.append((c as Vector3) - out.normalized() * 0.03)
					Plating.facing(into, inner, -out, _t["livery"].get("hold", Color(0.2, 0.2, 0.2)))
					continue
			if _glazed(mid.x, high, here):
				Plating.facing(screen, quad, out, _t["livery"]["glass"])
				continue
			Plating.facing(tool, quad, out, _body_tint(high, here))
	var nose: Vector2 = _t["nose_tip"]
	var tip: Vector3 = point(0.0, drawn(nose.y), nose.x)
	var first: Array = rings[0]
	for k in range(n):
		var mid_k: Vector3 = ((first[k] as Vector3) + first[(k + 1) % n]) * 0.5
		_fan(tool, tip, first[k], first[(k + 1) % n], Vector3.FORWARD, _body_tint(mid_k.y + _half.y, 0.001))
	var tail: Vector2 = _t["tail_tip"]
	var back: Vector3 = point(0.0, drawn(tail.y), tail.x)
	var last: Array = rings[rings.size() - 1]
	for k in range(n):
		_fan(tool, back, last[k], last[(k + 1) % n], Vector3.BACK, _t["livery"]["tail_cone"])


## THE SKIN'S HALF-WIDTH at a station and a height, on the drawn facets: where a window or a fairing lies on the side.
func skin_out(s: float, high: float) -> float:
	var half: Array = _half_ring(s)
	for i in range(half.size() - 1):
		var a: Vector2 = half[i]
		var b: Vector2 = half[i + 1]
		if (high <= a.y and high >= b.y) or (high >= a.y and high <= b.y):
			if absf(a.y - b.y) < 1e-6:
				return maxf(a.x, b.x)
			return lerpf(a.x, b.x, (high - a.y) / (b.y - a.y))
	return 0.0


## WHETHER A BOX, craft-local, IS INSIDE THE DRAWN FUSELAGE: every corner between the nose and the tail, and no further out
## than the section `_half_ring` draws is wide at its height, a centimetre in for the skin. Asked by
## `VehicleView.holster_fits`, as the Duo Discus's and the V-22's are, so a seat's signal-lamp holster is hung where the skin
## covers it; the same ring the fuselage is drawn from, so the answer cannot disagree with the picture.
func encloses(box: AABB) -> bool:
	for corner in range(8):
		var p: Vector3 = box.get_endpoint(corner)
		var s: float = p.z + _half.z
		if s <= 0.0 or s >= _half.z * 2.0:
			return false
		if absf(p.x) > skin_out(s, p.y + _half.y) - 0.01:
			return false
	return true


## THE CABIN WINDOWS, one dark pane per window a side, 6 mm proud of the facet they sit on, at each row's pitch from its
## first station to its last, with the stations in its `gaps` (the doors) left out. `cabin_windows` is one row or a list
## of rows (the 747's main deck and upper deck).
func _cabin_windows(tool: SurfaceTool) -> void:
	var rows: Array = _t["cabin_windows"] if _t["cabin_windows"] is Array else [_t["cabin_windows"]]
	for row in rows:
		var w: Dictionary = row
		var high: float = drawn(float(w["centre"]))
		var half_h: float = float(w["tall"]) * 0.5
		var half_w: float = float(w["wide"]) * 0.5
		var s: float = float(w["from"])
		while s <= float(w["to"]) + 0.001:
			var skip: bool = false
			for gap in w["gaps"]:
				if s > float(gap[0]) and s < float(gap[1]):
					skip = true
			if not skip:
				for side in [1.0, -1.0]:
					var lo: float = skin_out(s, high - half_h)
					var hi: float = skin_out(s, high + half_h)
					var corners: Array = [point(side * (hi + 0.006), high + half_h, s - half_w),
						point(side * (hi + 0.006), high + half_h, s + half_w),
						point(side * (lo + 0.006), high - half_h, s + half_w),
						point(side * (lo + 0.006), high - half_h, s - half_w)]
					Plating.facing(tool, corners, Vector3(side, 0.0, 0.0), _t["livery"]["window"])
			s += float(w["pitch"])


## THE WING-TO-BODY FAIRING: a flat-sided keel box under the wing root, from the table, that carries the belly out to
## the wing's underside and makes the main wheel well.
func _wing_to_body_fairing(tool: SurfaceTool) -> void:
	var f: Dictionary = _t["fairing"]
	var loops: Array = []
	for row in f["rows"]:
		var s: float = float(row[0])
		var wide: float = float(row[1])
		var low: float = drawn(float(row[2]))
		var top: float = drawn(float(row[3]))
		loops.append([point(wide, top, s), point(wide, low + 0.25, s), point(wide * 0.6, low, s),
			point(-wide * 0.6, low, s), point(-wide, low + 0.25, s), point(-wide, top, s)])
	_loft(tool, loops, [_t["livery"]["belly"]])


# ---- the wing -----------------------------------------------------------------------------------------------------------

## The wing's leading edge, trailing edge and chord-plane height at `out`, from the table's breakpoints.
func _along(key: String, out: float) -> float:
	var rows: Array = _t["wing"][key]
	if out <= float(rows[0][0]):
		return float(rows[0][1])
	for i in range(rows.size() - 1):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		if out <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (out - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(rows[-1][1])


func wing_le(out: float) -> float:
	return _along("le", out)


func wing_te(out: float) -> float:
	return _along("te", out)


## THE WING'S LOWER SURFACE, drawn, at `out`: the front view's fitted line.
func wing_lower(out: float) -> float:
	var line: Vector2 = _t["wing"]["lower"]
	return line.x + line.y * out


## THE WING'S THICKNESS at `out`: the table's `thick` breakpoints in metres where it has them (the 747's, off the front
## view), or its thickness-to-chord interpolated root to tip, times the chord.
func wing_thick(out: float) -> float:
	var w: Dictionary = _t["wing"]
	if w.has("thick"):
		return _along("thick", out)
	var tc: Vector2 = w["tc"]
	var f: float = clampf((out - float(w["root"])) / (float(w["tip"]) - float(w["root"])), 0.0, 1.0)
	return lerpf(tc.x, tc.y, f) * (wing_te(out) - wing_le(out))


## THE CHORD PLANE at `out`: the table's `mid` breakpoints (drawn heights) where it has them, or half the thickness over
## the lower surface; raised.
func wing_h(out: float) -> float:
	if (_t["wing"] as Dictionary).has("mid"):
		return drawn(_along("mid", out))
	return drawn(wing_lower(out)) + wing_thick(out) * 0.5


## A SIX-POINT SECTION of a lifting surface: leading edge, two on the upper surface at 15 and 50 per cent, trailing edge,
## two on the lower. `at` places a (chordwise, thickness) pair; the section's own `thick` is the whole depth.
static func _section(le: float, te: float, thick: float, at: Callable) -> Array:
	var c: float = te - le
	var t: float = thick * 0.5
	return [at.call(le, 0.0), at.call(le + 0.15 * c, t * 0.8), at.call(le + 0.5 * c, t), at.call(te, 0.0),
		at.call(le + 0.5 * c, -t), at.call(le + 0.15 * c, -t * 0.8)]


## THE WING SECTION at `out` (signed), from `le` to `te`.
func _wing_section(out: float, le: float, te: float) -> Array:
	var o: float = absf(out)
	var h: float = wing_h(o)
	var sign: float = signf(out)
	return _section(le, te, wing_thick(o), func(s: float, up: float) -> Vector3: return point(sign * o, h + up, s))


func _upper_tints() -> Array:
	var top: Color = _t["livery"]["wing"]
	var under: Color = _t["livery"]["wing_under"]
	return [top, top, top, under, under, under]


## THE WING, one side: from the root (buried in the fuselage) through the table's spanwise stations to the winglet's foot.
## The flaps, the ailerons and the spoilers are cut out of the chord where they are (`_cut`), each its own part on a hinge,
## so the fixed wing is lofted panel by panel: full chord where nothing moves, to the hinge where something does.
func _wing(tool: SurfaceTool, side: float) -> void:
	var w: Dictionary = _t["wing"]
	var stations: Array = (w["stations"] as Array).duplicate()
	var tints: Array = _upper_tints()
	for i in range(stations.size() - 1):
		var a: float = float(stations[i])
		var b: float = float(stations[i + 1])
		var mid: float = (a + b) * 0.5
		var cut: float = _cut(mid)
		_loft(tool, [_wing_section(side * a, wing_le(a), wing_te(a) - cut * (wing_te(a) - wing_le(a))),
			_wing_section(side * b, wing_le(b), wing_te(b) - cut * (wing_te(b) - wing_le(b)))], tints)


## THE SHARE OF THE CHORD cut away at `out` for a moving surface on the trailing edge: a flap's or an aileron's.
func _cut(out: float) -> float:
	for surface in _t["wing"]["trailing"]:
		if out > float(surface["from"]) and out < float(surface["to"]):
			return float(surface["chord"])
	return 0.0


## THE WINGLET, one side: sections from the wing tip up to the winglet's top, from the table's rows
## [out, drawn height, leading edge, trailing edge, thickness].
func _winglet(tool: SurfaceTool, side: float) -> void:
	var loops: Array = []
	var w: Dictionary = _t["wing"]
	if not w.has("winglet"):
		return
	var tip: float = float(w["tip"])
	loops.append(_wing_section(side * tip, wing_le(tip), wing_te(tip)))
	for row in w["winglet"]:
		var o: float = float(row[0])
		var h: float = drawn(float(row[1]))
		loops.append(_section(float(row[2]), float(row[3]), float(row[4]),
			func(s: float, up: float) -> Vector3: return point(side * (o + up * 0.35), h + up * 0.2, s)))
	_loft(tool, loops, _upper_tints())


## THE MOVING SURFACES ON ONE WING: each flap and aileron hinged along its leading edge on the wing's chord plane, turning
## trailing edge down; each spoiler a plate on the upper surface hinged at its front edge, turning up.
func _wing_surfaces(side: float, named: String, paint: Material) -> void:
	var tints: Array = _upper_tints()
	for surface in _t["wing"]["trailing"]:
		var title: String = String(surface["name"]) + named
		var a: float = float(surface["from"]) + 0.02
		var b: float = float(surface["to"]) - 0.02
		var chord: float = float(surface["chord"])
		var hinge_a: Vector3 = point(side * a, wing_h(a), wing_te(a) - chord * (wing_te(a) - wing_le(a)))
		var hinge_b: Vector3 = point(side * b, wing_h(b), wing_te(b) - chord * (wing_te(b) - wing_le(b)))
		var mid: Vector3 = (hinge_a + hinge_b) * 0.5
		var hinge := _hinge(title, self, mid, hinge_b - hinge_a, mid + Vector3.BACK, Vector3.DOWN)
		var tool := _tool()
		var loops: Array = []
		for o in [a, b]:
			var le: float = wing_te(o) - chord * (wing_te(o) - wing_le(o)) + 0.01
			var h: float = wing_h(o)
			var depth: float = wing_thick(o) * 0.7
			loops.append(_section(le, wing_te(o), depth,
				func(s: float, up: float) -> Vector3: return point(side * o, h + up, s) - hinge.position))
		_loft(tool, loops, tints)
		_add(hinge, title, tool, paint)
	# THE SPOILERS, a group of panels to a part on ONE hinge: every panel of a group lies between the same two straight
	# edges of the wing at the same shares of the chord, so their front edges are one straight line and one hinge turns
	# them all -- the bus has one spoiler bit, and a part a panel was twelve draw calls on the 747.
	for group in _t["wing"]["spoilers"]:
		var title: String = String(group["name"]) + named
		var panels: Array = group["panels"]
		var fore: float = float(group["fore"])
		var aft: float = float(group["aft"])
		# Fore and aft as shares of the chord, the plate lying 1 cm over the upper surface.
		var at := func(o: float, share: float) -> Vector3:
			var s: float = lerpf(wing_le(o), wing_te(o), share)
			return point(side * o, wing_h(o) + wing_thick(o) * 0.5 * _upper_share(share) + 0.01, s)
		var hinge_a: Vector3 = at.call(float(panels[0][0]), fore)
		var hinge_b: Vector3 = at.call(float(panels[-1][1]), fore)
		var mid: Vector3 = (hinge_a + hinge_b) * 0.5
		var hinge := _hinge(title, self, mid, hinge_b - hinge_a, mid + Vector3.BACK, Vector3.UP)
		var tool := _tool()
		for panel in panels:
			var a: float = float(panel[0]) + 0.02
			var b: float = float(panel[1]) - 0.02
			var corners: Array = [at.call(a, fore), at.call(b, fore), at.call(b, aft), at.call(a, aft)]
			var centre: Vector3 = ((corners[0] as Vector3) + corners[1] + corners[2] + corners[3]) * 0.25
			var thick: Vector3 = Vector3.UP * 0.012
			var face: Array = []
			var back: Array = []
			for c in corners:
				face.append((c as Vector3) - hinge.position + thick)
				back.append((c as Vector3) - hinge.position - thick)
			Plating.facing(tool, face, Vector3.UP, _t["livery"]["wing"])
			Plating.facing(tool, back, Vector3.DOWN, _t["livery"]["wing_under"])
			for k in range(4):
				var k2: int = (k + 1) % 4
				var edge_mid: Vector3 = ((face[k] as Vector3) + face[k2]) * 0.5
				Plating.facing(tool, [face[k], face[k2], back[k2], back[k]], edge_mid - (centre - hinge.position),
					_t["livery"]["wing"])
		_add(hinge, title, tool, paint)


## THE UPPER SURFACE'S HEIGHT as a share of the half-thickness at a share of the chord, on the six-point section: 0.8 at
## 15 per cent, 1.0 at half, falling to 0 at the trailing edge.
static func _upper_share(share: float) -> float:
	if share <= 0.15:
		return lerpf(0.0, 0.8, share / 0.15)
	if share <= 0.5:
		return lerpf(0.8, 1.0, (share - 0.15) / 0.35)
	return lerpf(1.0, 0.0, (share - 0.5) / 0.5)


# ---- the engines --------------------------------------------------------------------------------------------------------

## ONE NACELLE, from the table's row: a 12-sided pod from the inlet lip through its widest ring to the cowl's end, the
## nozzle behind it and the plug. The ring is an ellipse `wide` by `tall`, its bottom flattened by `flat` (the 737's
## CFM56 sits so close to the ground that its lower lip is flat). A dark inlet face set back in the lip.
func _nacelle(tool: SurfaceTool, n: Dictionary) -> void:
	var out: float = float(n["out"])
	var h: float = drawn(float(n["high"]))
	var ring := func(s: float, wide: float, tall: float, flat: float) -> Array:
		var loop: Array = []
		for k in range(NACELLE_SIDES):
			var a: float = TAU * (float(k) + 0.5) / NACELLE_SIDES
			var y: float = cos(a) * tall
			if y < 0.0:
				y *= (1.0 - flat)
			loop.append(point(out + sin(a) * wide, h + y, s))
		return loop
	var skin: Color = _t["livery"]["nacelle"]
	var lip: Color = _t["livery"]["lip"]
	var loops: Array = []
	for row in n["rings"]:
		loops.append(ring.call(float(row[0]), float(row[1]), float(row[2]), float(n["flat"])))
	var tints: Array = [skin]
	# THE LIP, its own colour, from the first ring to the second.
	var lip_loops: Array = [loops[0], loops[1]]
	_loft(tool, lip_loops, [lip], false)
	_loft(tool, loops.slice(1), tints, false)
	# THE INLET FACE: a dark disc set back 0.25 m inside the first ring, walled to it.
	var first: Array = loops[0]
	var face_s: float = float(n["rings"][0][0]) + 0.25
	var face: Array = ring.call(face_s, float(n["rings"][0][1]) * 0.9, float(n["rings"][0][2]) * 0.9, float(n["flat"]))
	var centre: Vector3 = point(out, h, face_s)
	for k in range(NACELLE_SIDES):
		var k2: int = (k + 1) % NACELLE_SIDES
		var wall: Array = [first[k], first[k2], face[k2], face[k]]
		var wmid: Vector3 = ((wall[0] as Vector3) + wall[1] + wall[2] + wall[3]) * 0.25
		Plating.facing(tool, wall, Vector3(centre.x - wmid.x, centre.y - wmid.y, 0.0), _t["livery"]["inlet"])
		_fan(tool, centre, face[k], face[k2], Vector3.FORWARD, _t["livery"]["inlet"])
	# THE NOZZLE AND THE PLUG: a smaller ring from the cowl's end, closed by a cone.
	var last: Array = loops[loops.size() - 1]
	var nozzle: Array = n["nozzle"]
	var noz: Array = ring.call(float(nozzle[0]), float(nozzle[1]), float(nozzle[1]), 0.0)
	var metal: Color = _t["livery"]["metal"]
	_loft(tool, [last, noz], [metal], false)
	var plug: Vector3 = point(out, h, float(n["plug"]))
	for k in range(NACELLE_SIDES):
		_fan(tool, plug, noz[k], noz[(k + 1) % NACELLE_SIDES], Vector3.BACK, metal)


## THE PYLON: a flat-sided blade from the nacelle's top to the wing's underside, from the table's [fore, aft] stations.
func _pylon(tool: SurfaceTool, n: Dictionary) -> void:
	if not n.has("pylon"):
		return
	var out: float = float(n["out"])
	var p: Array = n["pylon"]
	var fore: float = float(p[0])
	var aft: float = float(p[1])
	var half: float = float(p[2])
	var h: float = drawn(float(n["high"]))
	var top_of_pod: float = h + float(n["rings"][2][2]) * 0.8
	var under_wing := func(s: float) -> float:
		return wing_h(out) - wing_thick(out) * 0.5 * (0.6 if s < wing_le(out) + 0.5 else 0.9) + 0.12
	var loops: Array = []
	for s in [fore, (fore + aft) * 0.5, aft]:
		var top: float = maxf(float(under_wing.call(s)), top_of_pod + 0.2)
		loops.append([point(out + half, top, s), point(out + half, top_of_pod - 0.1, s),
			point(out - half, top_of_pod - 0.1, s), point(out - half, top, s)])
	_loft(tool, loops, [_t["livery"]["nacelle"]])


# ---- the tail -----------------------------------------------------------------------------------------------------------

func tail_le(out: float) -> float:
	var t: Dictionary = _t["tailplane"]
	return (t["le"] as Vector2).x + (t["le"] as Vector2).y * out


func tail_te(out: float) -> float:
	var t: Dictionary = _t["tailplane"]
	return (t["te"] as Vector2).x + (t["te"] as Vector2).y * out


func tail_h(out: float) -> float:
	var t: Dictionary = _t["tailplane"]
	var f: float = clampf((out - float(t["root"])) / (float(t["tip"]) - float(t["root"])), 0.0, 1.0)
	return drawn(lerpf((t["high"] as Vector2).x, (t["high"] as Vector2).y, f))


func _tail_section(out: float, te_cut: float) -> Array:
	var o: float = absf(out)
	var sign: float = signf(out)
	var le: float = tail_le(o)
	var te: float = tail_te(o)
	var h: float = tail_h(o)
	var tc: float = float(_t["tailplane"]["tc"])
	return _section(le, te - te_cut * (te - le), tc * (te - le),
		func(s: float, up: float) -> Vector3: return point(sign * o, h + up, s))


## THE TAILPLANE, one side, with the elevator's chord cut from its trailing edge where the elevator is.
func _tailplane(tool: SurfaceTool, side: float) -> void:
	var t: Dictionary = _t["tailplane"]
	var root: float = float(t["root"])
	var tip: float = float(t["tip"])
	var e: Array = t["elevator"]
	var tints: Array = [_t["livery"]["tail"], _t["livery"]["tail"], _t["livery"]["tail"], _t["livery"]["wing_under"],
		_t["livery"]["wing_under"], _t["livery"]["wing_under"]]
	_loft(tool, [_tail_section(side * root, 0.0), _tail_section(side * float(e[0]), 0.0)], tints)
	_loft(tool, [_tail_section(side * float(e[0]), float(e[2])), _tail_section(side * float(e[1]), float(e[2]))], tints)
	_loft(tool, [_tail_section(side * float(e[1]), 0.0), _tail_section(side * tip, 0.0)], tints)


## THE ELEVATOR, one side, on its hinge along the cut; trailing edge down for a positive turn.
func _elevator(side: float, named: String, paint: Material) -> void:
	var e: Array = _t["tailplane"]["elevator"]
	var a: float = float(e[0]) + 0.02
	var b: float = float(e[1]) - 0.02
	var chord: float = float(e[2])
	var edge := func(o: float) -> float: return tail_te(o) - chord * (tail_te(o) - tail_le(o))
	var hinge_a: Vector3 = point(side * a, tail_h(a), float(edge.call(a)))
	var hinge_b: Vector3 = point(side * b, tail_h(b), float(edge.call(b)))
	var mid: Vector3 = (hinge_a + hinge_b) * 0.5
	var hinge := _hinge("Elevator" + named, self, mid, hinge_b - hinge_a, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var tc: float = float(_t["tailplane"]["tc"])
	var loops: Array = []
	for o in [a, b]:
		var h: float = tail_h(o)
		var le: float = float(edge.call(o)) + 0.01
		loops.append(_section(le, tail_te(o), tc * (tail_te(o) - tail_le(o)) * 0.7,
			func(s: float, up: float) -> Vector3: return point(side * o, h + up, s) - hinge.position))
	var tint: Color = _t["livery"]["tail"]
	_loft(tool, loops, [tint, tint, tint, tint, tint, tint])
	_add(hinge, "Elevator" + named, tool, paint)


## THE FIN'S LEADING AND TRAILING EDGES at a drawn height, from the table's lines.
func fin_le(high: float) -> float:
	var f: Dictionary = _t["fin"]
	return (f["le"] as Vector2).x + (f["le"] as Vector2).y * high


func fin_te(high: float) -> float:
	var f: Dictionary = _t["fin"]
	return (f["te"] as Vector2).x + (f["te"] as Vector2).y * high


## A FIN SECTION at a drawn height (the table's, before the fin is shortened to its published tip: see `_fin_high`).
func _fin_section(drawn_h: float, le: float, te: float) -> Array:
	var f: Dictionary = _t["fin"]
	var thick: Vector2 = f["thick"]
	var share: float = clampf((drawn_h - float(f["root"])) / (float(f["tip"]) - float(f["root"])), 0.0, 1.0)
	var h: float = _fin_high(drawn_h)
	return _section(le, te, lerpf(thick.x, thick.y, share),
		func(s: float, across: float) -> Vector3: return point(across, h, s))


## THE FIN'S HEIGHT IN THE CRAFT, for a drawn height: the root is raised with the body, and the tip is put at the table's
## `tip_over_ground` -- see the aeroplane's table for why the fin is the one part not simply raised.
func _fin_high(drawn_h: float) -> float:
	var f: Dictionary = _t["fin"]
	var root: float = float(f["root"])
	var tip: float = float(f["tip"])
	var share: float = (drawn_h - root) / (tip - root)
	return lerpf(drawn(root), float(f["tip_over_ground"]), share)


## THE FIN: sections at the dorsal fillet's heights, up the fin's leading edge to the rudder's top and on to the tip,
## the rudder's chord cut from the trailing edge up to the rudder's top. Two lofts meet at the rudder's top: one with the
## cut and one without.
func _fin(tool: SurfaceTool) -> void:
	var f: Dictionary = _t["fin"]
	var tint: Color = _t["livery"]["fin"]
	var tints: Array = [tint, tint, tint, tint, tint, tint]
	var dorsal: Array = f["dorsal"]
	var r: Array = f["rudder"]
	var last_dorsal: float = float(dorsal[-1][0])
	var le_at := func(h: float) -> float:
		if h <= last_dorsal + 0.001:
			for i in range(dorsal.size() - 1):
				if h <= float(dorsal[i + 1][0]):
					return lerpf(float(dorsal[i][1]), float(dorsal[i + 1][1]),
						(h - float(dorsal[i][0])) / (float(dorsal[i + 1][0]) - float(dorsal[i][0])))
			return float(dorsal[0][1])
		return fin_le(h)
	var cut_loops: Array = []
	for row in dorsal:
		var h: float = float(row[0])
		cut_loops.append(_fin_section(h, float(le_at.call(h)), fin_te(h) - rudder_chord(h)))
	var top: float = float(r[1])
	cut_loops.append(_fin_section(top, float(le_at.call(top)), fin_te(top) - rudder_chord(top)))
	_loft(tool, cut_loops, tints)
	var tip: float = float(f["tip"])
	_loft(tool, [_fin_section(top, float(le_at.call(top)), fin_te(top)),
		_fin_section(tip, float(le_at.call(tip)), fin_te(tip))], tints)


## THE RUDDER'S CHORD at a drawn height, root to tip.
func rudder_chord(high: float) -> float:
	var f: Dictionary = _t["fin"]
	var r: Array = f["rudder"]
	var share: float = clampf((high - float(f["root"])) / (float(f["tip"]) - float(f["root"])), 0.0, 1.0)
	return lerpf(float(r[2]), float(r[3]), share)


## THE RUDDER on its hinge along the cut; a positive turn swings the trailing edge to STARBOARD, for right rudder.
func _rudder(paint: Material) -> void:
	var f: Dictionary = _t["fin"]
	var r: Array = f["rudder"]
	var root: float = float(f["root"])
	var tip: float = float(f["tip"])
	var low: float = float(r[0])
	var high: float = float(r[1])
	var foot: Vector3 = point(0.0, _fin_high(low), fin_te(low) - rudder_chord(low))
	var head: Vector3 = point(0.0, _fin_high(high), fin_te(high) - rudder_chord(high))
	var hinge := _hinge("Rudder", self, foot, head - foot, foot + Vector3.BACK, Vector3.RIGHT)
	var tool := _tool()
	var loops: Array = []
	var thick: Vector2 = f["thick"]
	for h in [low + 0.02, high - 0.02]:
		var share: float = clampf((float(h) - root) / (tip - root), 0.0, 1.0)
		var y: float = _fin_high(float(h))
		loops.append(_section(fin_te(float(h)) - rudder_chord(float(h)) + 0.01, fin_te(float(h)),
			lerpf(thick.x, thick.y, share) * 0.6,
			func(s: float, across: float) -> Vector3: return point(across, y, s) - foot))
	var tint: Color = _t["livery"]["fin"]
	_loft(tool, loops, [tint, tint, tint, tint, tint, tint])
	_add(hinge, "Rudder", tool, paint)


# ---- the ramp -----------------------------------------------------------------------------------------------------------

## THE CARGO RAMP AND THE UPPER CARGO DOOR, where the table has a `ramp`: the ramp is the belly's skin from the hinge at
## the cargo floor's end to `end`, and swings DOWN about the hinge until its tail is on the ground; the door is the skin
## from there to `door_end`, and swings UP into the tail about its aft edge. `set_ramp` opens both together.
func _build_ramp(paint: Material) -> void:
	if _ramp_tools.is_empty():
		return
	var r: Dictionary = _t["ramp"]
	var hinge_s: float = float(r["hinge"])
	var at: Vector3 = point(0.0, drawn(_column(hinge_s, 2)), hinge_s)
	var ramp_hinge := _hinge("Ramp", self, at, Vector3.RIGHT, at + Vector3.BACK, Vector3.DOWN)
	var door_s: float = float(r["door_end"])
	var door_at: Vector3 = point(0.0, drawn(_column(door_s, 2)), door_s)
	var door_hinge := _hinge("CargoDoor", self, door_at, Vector3.RIGHT, door_at + Vector3.FORWARD, Vector3.UP)
	for pair in [[ramp_hinge, "Ramp", 0], [door_hinge, "CargoDoor", 1]]:
		var hinge: Node3D = pair[0]
		var tool: SurfaceTool = _ramp_tools[int(pair[2])]
		var mesh := _add(hinge, String(pair[1]), tool, paint)
		# The skin was built in the craft's frame; the part hangs from its hinge.
		mesh.position = -hinge.position
	# THE CARGO FLOOR, a dark plate at the floor's height from the flight deck's bulkhead to the ramp's hinge, so an
	# open ramp shows a hold rather than the far side's skin.
	var floor_tool := _tool()
	var fl: Vector3 = r["floor"]
	var y: float = drawn(fl.z)
	Plating.facing(floor_tool, [point(-fl.x, y, fl.y), point(fl.x, y, fl.y), point(fl.x, y, hinge_s - 0.02),
		point(-fl.x, y, hinge_s - 0.02)], Vector3.UP, _t["livery"]["hold"])
	_add(self, "CargoFloor", floor_tool, paint)


## THE RAMP, 0 shut to 1 open: the ramp down to the ground and the upper door up into the tail, together.
func set_ramp(amount: float) -> void:
	_ramp = clampf(amount, 0.0, 1.0)
	if not _t.has("ramp"):
		return
	var r: Dictionary = _t["ramp"]
	_turn("Ramp", _ramp * deg_to_rad(float(r["open"])))
	_turn("CargoDoor", _ramp * deg_to_rad(float(r["door_open"])))


func ramp() -> float:
	return _ramp


# ---- the gear -----------------------------------------------------------------------------------------------------------

## THE GEAR: each leg of the table on its pivot, built DOWN and turned into its well by the shortest arc from its down
## direction to its stowed one, and the well doors the table names.
func _build_gear(paint: Material) -> void:
	for leg in _t["gear"]:
		var l: Dictionary = leg
		var sides: Array = [1.0, -1.0] if float(l["out"]) > 0.0 else [0.0]
		for side in sides:
			var named: String = String(l["name"]) + ("" if side == 0.0 else ("Starboard" if side > 0.0 else "Port"))
			_leg(named, l, 1.0 if side == 0.0 else float(side), paint)
	for door in _t.get("gear_doors", []):
		var d: Dictionary = door
		for side in [1.0, -1.0]:
			var named: String = String(d["name"]) + ("Starboard" if side > 0.0 else "Port")
			var fore: float = float(d["fore"])
			var aft: float = float(d["aft"])
			var inner: float = side * float(d["inner"])
			var outer: float = side * float(d["outer"])
			var under := func(s: float, o: float) -> float:
				return drawn(_column(s, 2)) + 0.012 + absf(o) * 0.02
			var corners: Array = [point(inner, under.call(fore, inner), fore), point(outer, under.call(fore, outer), fore),
				point(outer, under.call(aft, outer), aft), point(inner, under.call(aft, inner), aft)]
			_door(named, corners, corners[1], corners[2], Vector3.DOWN, Vector3.DOWN, paint)


## ONE LEG: a pivot at `pivot`, built with the axle at `axle` and stowed turning the axle to `stowed` (each [out, drawn
## or ground height, station]; the axle's height is over the GROUND, the pivot's and the stowed axle's are drawn, since
## they are in the body), a strut and its tyres across the axle. A leg's own door rides on the leg.
func _leg(named: String, l: Dictionary, side: float, paint: Material) -> void:
	var p: Vector3 = l["pivot"]
	var x: Vector3 = l["axle"]
	var st: Vector3 = l["stowed"]
	var pivot_at: Vector3 = point(side * p.x, drawn(p.y), p.z)
	var tyre: Vector2 = l["tyre"]
	var axle: Vector3 = point(side * x.x, tyre.x * 0.5, x.z)
	var stowed: Vector3 = point(side * st.x, drawn(st.y), st.z)
	var pivot := Node3D.new()
	pivot.name = named + "Pivot"
	pivot.position = pivot_at
	add_child(pivot)
	_legs.append(pivot)
	_leg_down.append(pivot_at)
	# A LEG THAT SLIDES (the C-130's mains, which rise straight up into their sponsons) is stowed by moving the axle to
	# `stowed`, not by turning it there.
	if bool(l.get("slide", false)):
		_stowed.append(Quaternion.IDENTITY)
		_slides.append(stowed - axle)
	else:
		_stowed.append(Quaternion((axle - pivot_at).normalized(), (stowed - pivot_at).normalized()))
		_slides.append(Vector3.ZERO)
	var tool := _tool()
	var along: Vector3 = (axle - pivot_at).normalized()
	var across: Vector3 = along.cross(Vector3.FORWARD).normalized()
	if across.length_squared() < 0.5:
		across = Vector3.RIGHT
	var up: Vector3 = across.cross(along).normalized()
	var h: float = float(l["strut"])
	var gear_tint: Color = _t["livery"]["gear"]
	var loops: Array = []
	for q in [Vector3.ZERO, axle - pivot_at]:
		loops.append([q + across * h + up * h, q - across * h + up * h, q - across * h - up * h, q + across * h - up * h])
	_loft(tool, loops, [gear_tint])
	# THE AXLE ACROSS and the TYRES on it, each an eight-sided prism whose bottom FLAT stands on the ground.
	var centre: Vector3 = axle - pivot_at
	var spread: Array = l["tyres"]
	# A BOGIE (the 747's): axles fore and aft of the leg's foot, on a beam along it.
	var axles: Array = l.get("axles", [0.0])
	var reach: float = 0.0
	for o in spread:
		reach = maxf(reach, absf(float(o)))
	var apothem: float = tyre.x * 0.5
	var corner: float = apothem / cos(PI / WHEEL_SIDES)
	if axles.size() > 1:
		Plating.box(tool, centre + Vector3(0.0, 0.0, (float(axles[0]) + float(axles[-1])) * 0.5),
			Vector3(h * 1.4, h * 1.4, absf(float(axles[-1]) - float(axles[0])) + h), gear_tint)
	for z in axles:
		var at: Vector3 = centre + Vector3(0.0, 0.0, float(z))
		Plating.box(tool, at, Vector3(reach * 2.0, h, h), gear_tint)
		for o in spread:
			var wheel: Array = []
			for w in [-tyre.y * 0.5, tyre.y * 0.5]:
				var loop: Array = []
				for k in range(WHEEL_SIDES):
					var t: float = TAU * (float(k) + 0.5) / WHEEL_SIDES
					loop.append(at + Vector3(float(o) + w, corner * cos(t), corner * sin(t)))
				wheel.append(loop)
			_loft(tool, wheel, [_t["livery"]["tyre"]])
	if l.has("leg_door"):
		var door: Vector2 = l["leg_door"]
		var off: Vector3 = Vector3(side * door.x, 0.0, 0.0)
		var top: Vector3 = off + along * 0.10
		var bottom: Vector3 = off + along * ((axle - pivot_at).length() - apothem - 0.1)
		Plating.box(tool, (top + bottom) * 0.5, Vector3(0.03, (bottom - top).length(), door.y), _t["livery"]["belly"],
			Basis(Quaternion(Vector3.DOWN, along)))
	var mesh := _add(pivot, named, tool, paint)
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = DETAIL_HYSTERESIS
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## A DOOR: a flat plate on its own hinge, painted outside on the face that faces `out` when shut and grey inside.
func _door(named: String, corners: Array, hinge_a: Vector3, hinge_b: Vector3, opens_towards: Vector3, out: Vector3,
		paint: Material) -> Node3D:
	var mid: Vector3 = Vector3.ZERO
	for c in corners:
		mid += c
	mid /= float(corners.size())
	var at: Vector3 = (hinge_a + hinge_b) * 0.5
	var hinge := _hinge(named, self, at, hinge_b - hinge_a, mid, opens_towards)
	var tool := _tool()
	var thick: Vector3 = out.normalized() * 0.012
	var face: Array = []
	var back: Array = []
	for c in corners:
		face.append((c as Vector3) - at + thick)
		back.append((c as Vector3) - at - thick)
	Plating.facing(tool, face, out, _t["livery"]["belly"])
	Plating.facing(tool, back, -out, _t["livery"]["gear"])
	for k in range(corners.size()):
		var k2: int = (k + 1) % corners.size()
		var edge_mid: Vector3 = ((face[k] as Vector3) + face[k2]) * 0.5
		Plating.facing(tool, [face[k], face[k2], back[k2], back[k]], edge_mid - (mid - at), _t["livery"]["belly"])
	_add(hinge, named, tool, paint)
	return hinge


# ---- what moves ---------------------------------------------------------------------------------------------------------

## THE GEAR, 0 up and 1 down: doors open, legs travel, doors shut. A leg never moves while its well doors are shut.
func set_gear(amount: float) -> void:
	_gear = clampf(amount, 0.0, 1.0)
	var legs: float = legs_down(_gear)
	for index in range(_legs.size()):
		_legs[index].basis = Basis(Quaternion.IDENTITY.slerp(_stowed[index], 1.0 - legs))
		_legs[index].position = _leg_down[index] + _slides[index] * (1.0 - legs)
	var doors: float = well_doors_open(_gear)
	for door in _t.get("gear_doors", []):
		for named in ["Starboard", "Port"]:
			_turn(String((door as Dictionary)["name"]) + named, doors * WELL_OPEN)


func gear() -> float:
	return _gear


## HOW FAR DOWN THE LEGS ARE at a gear amount: still over the doors' shares, eased over the middle.
static func legs_down(amount: float) -> float:
	return smoothstep(DOORS_OPEN_BY, DOORS_SHUT_FROM, amount)


## HOW OPEN THE WELL DOORS ARE at a gear amount: opening over the first share, open, shutting over the last.
static func well_doors_open(amount: float) -> float:
	if amount <= DOORS_OPEN_BY:
		return smoothstep(0.0, DOORS_OPEN_BY, amount)
	if amount >= DOORS_SHUT_FROM:
		return 1.0 - smoothstep(DOORS_SHUT_FROM, 1.0, amount)
	return 1.0


## THE FLAPS, 0 up to 1 at full travel: the bus's flaps lever (0 to 3) over three.
func set_flaps(amount: float) -> void:
	_flaps = clampf(amount, 0.0, 1.0)
	for surface in _t["wing"]["trailing"]:
		if String(surface["name"]).begins_with("Flap"):
			for named in ["Starboard", "Port"]:
				_turn(String(surface["name"]) + named, _flaps * FLAP_TRAVEL)


func flaps() -> float:
	return _flaps


## THE SPOILERS, 0 stowed to 1 up.
func set_spoilers(amount: float) -> void:
	_spoilers = clampf(amount, 0.0, 1.0)
	for group in _t["wing"]["spoilers"]:
		for named in ["Starboard", "Port"]:
			_turn(String(group["name"]) + named, _spoilers * SPOILER_TRAVEL)


func spoilers() -> float:
	return _spoilers


## THE STICK'S SURFACES: `roll` -1 left wing down to +1 right, `pitch` -1 nose down to +1 up, `yaw` -1 nose left to +1
## right. Right roll puts the starboard aileron UP and the port one down.
func set_ailerons(roll: float) -> void:
	_roll = clampf(roll, -1.0, 1.0)
	for surface in _t["wing"]["trailing"]:
		if String(surface["name"]).begins_with("Aileron"):
			_turn(String(surface["name"]) + "Starboard", -_roll * AILERON_TRAVEL)
			_turn(String(surface["name"]) + "Port", _roll * AILERON_TRAVEL)


func set_elevators(pitch: float) -> void:
	_pitch = clampf(pitch, -1.0, 1.0)
	_turn("ElevatorStarboard", -_pitch * ELEVATOR_TRAVEL)
	_turn("ElevatorPort", -_pitch * ELEVATOR_TRAVEL)


func set_rudder(yaw: float) -> void:
	_yaw = clampf(yaw, -1.0, 1.0)
	_turn("Rudder", _yaw * RUDDER_TRAVEL)


func stick_roll() -> float:
	return _roll


func stick_pitch() -> float:
	return _pitch


func stick_yaw() -> float:
	return _yaw


## THE FEATURES A VAT BAKES (`VatCasting`), each this airframe's own setter and getter.
func features() -> Array:
	return [
		{"name": "gear", "set": set_gear, "get": gear, "low": 0.0, "high": 1.0},
		{"name": "flaps", "set": set_flaps, "get": flaps, "low": 0.0, "high": 1.0, "samples": 33},
		{"name": "spoilers", "set": set_spoilers, "get": spoilers, "low": 0.0, "high": 1.0, "samples": 17},
		{"name": "pitch", "set": set_elevators, "get": stick_pitch, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "roll", "set": set_ailerons, "get": stick_roll, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "rudder", "set": set_rudder, "get": stick_yaw, "low": -1.0, "high": 1.0, "samples": 33},
	]


# ---- the crew -----------------------------------------------------------------------------------------------------------

## THE CAPTAIN'S EYE, craft-local: LEFT seat, as on every Boeing.
func eye() -> Vector3:
	var e: Vector3 = _t["eye"]
	return point(-e.x, drawn(e.y), e.z)


## THE FIRST OFFICER'S EYE: the right seat.
func first_officer_eye() -> Vector3:
	var e: Vector3 = _t["eye"]
	return point(e.x, drawn(e.y), e.z)


## THE SEAT under an eye, as a height over the ground.
func seat_height() -> float:
	return drawn((_t["eye"] as Vector3).y) - CockpitStation.EYE_HEIGHT


## THE ROOM THE FLIGHT CREW SITS IN, in the shape `VehicleView.cabin_room()` asks for: the table's box, in drawn
## heights, which the airframe's suite holds inside the drawn skin.
func cabin_room() -> Dictionary:
	var r: AABB = _t["room"]
	var low: Vector3 = point(r.position.x, drawn(r.position.y), r.position.z)
	var high: Vector3 = point(r.end.x, drawn(r.end.y), r.end.z)
	return {
		"drawn": true,
		"floor": point(0.0, seat_height() + 0.04, (_t["eye"] as Vector3).z).y,
		"room": AABB(low, high - low).abs(),
		"because": &"",
		"why_not": "",
		"source": String(_t["room_source"]),
	}


# ---- building -----------------------------------------------------------------------------------------------------------

## A HINGE turned `angle` radians from where it was built, about the axis stored on it when it was built.
func _turn(named: String, angle: float) -> void:
	var hinge: Node3D = _hinges.get(named) as Node3D
	if hinge != null:
		hinge.basis = Basis(hinge.get_meta("axis") as Vector3, angle)


## A HINGE at `at`, turning about `along`, wound so a small positive turn carries `probe` towards `wanted`: the Tomcat's
## way, so the builder never reasons about which way a mirrored hinge turns.
func _hinge(named: String, parent: Node3D, at: Vector3, along: Vector3, probe: Vector3, wanted: Vector3) -> Node3D:
	var hinge := Node3D.new()
	# "HINGE" ON THE END, so a hinge is never found in place of the part it carries (lane/tomcat2).
	hinge.name = named + "Hinge"
	hinge.position = at
	var axis: Vector3 = along.normalized()
	if axis.cross(probe - at).dot(wanted) < 0.0:
		axis = -axis
	hinge.set_meta("axis", axis)
	parent.add_child(hinge)
	_hinges[named] = hinge
	return hinge


static func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _add(parent: Node3D, title: String, tool: SurfaceTool, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


## ONE TRIANGLE, wound so its face looks along `out`.
static func _fan(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
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


## A LOFT through matching loops, each quad facing away from its own loops' middle, both ends closed by fans unless
## `close` is false.
static func _loft(tool: SurfaceTool, loops: Array, tints: Array, close: bool = true) -> void:
	var n: int = (loops[0] as Array).size()
	var centres: Array = []
	for loop in loops:
		var c := Vector3.ZERO
		for p in loop:
			c += p
		centres.append(c / float(n))
	for i in range(loops.size() - 1):
		var a: Array = loops[i]
		var b: Array = loops[i + 1]
		var mid_centre: Vector3 = ((centres[i] as Vector3) + centres[i + 1]) * 0.5
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			Plating.facing(tool, quad, mid - mid_centre, tints[k % tints.size()])
	if not close:
		return
	for end in [0, loops.size() - 1]:
		var along: Vector3 = (centres[end] as Vector3) - centres[1 if end == 0 else loops.size() - 2]
		var loop: Array = loops[end]
		for k in range(n):
			_fan(tool, centres[end], loop[k], loop[(k + 1) % n], along, tints[k % tints.size()])
