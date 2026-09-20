extends "res://tests/ship_models.gd"
## Headless: is the mahogany runabout the size her sources say, is she a boat by every check a warship is held to, and
## are the four things that make her a Chris-Craft rather than a brown boat actually DRAWN?
##
##   Godot --headless --xr-mode off --path cockpit --fixed-fps 120 res://tests/runabout.tscn
##
## THE FIGURES ARE TYPED FROM `craft/runabout/sources.md`, not read from `RunaboutDraft`, which would be the model
## agreeing with itself. Length and beam are PUBLISHED [S]; everything else about this boat is an estimate and the
## checks below are careful never to hold her to one of those. **Nothing here is checked against the published 28 in
## draught**, because `sources.md` shows that figure is measured to the running gear and the drawn hull is deliberately
## not that deep -- checking it would be this suite asking a question it already knows is the wrong one.
##
## ## THE CHECK THIS SUITE EXISTS FOR
##
## `_the_white_stripe_is_actually_drawn`. The boot stripe went missing TWICE while the boat was being built, both times
## silently and both times for a reason inside `HullLoft` rather than inside the boat: it paints a row GAP and picks
## the colour from that gap's MIDPOINT, so a perfectly sensible set of sections can step straight over the waterline
## and paint no stripe at all -- and then, once two rows straddle it, the stripe's WIDTH is the row spacing and not
## `BOOT`, so the obvious knob does nothing. **Every check that looked at the hull passed both times, because the hull
## was right.** Only a picture found it. So the check asks what is DRAWN and where, in the stripe's own colour, and it
## asks for a width as well as an existence -- a stripe 0.14 m wide on a boat with 0.50 m of freeboard is a lifebuoy
## band and is as wrong as no stripe.
##
## ## AND THE ONE THAT ENCODES THE FILE'S CENTRAL CLAIM
##
## `_the_deck_is_the_same_wood_as_the_topsides`. A photograph's pixel is albedo times light and a vertex colour is
## albedo alone, so the deck -- which reads much lighter in all three references because it faces the sky -- must be
## drawn in exactly the topsides' colour and lit lighter by the game. That is a sentence in three doc blocks and a
## sentence cannot go red. This asks for one mahogany, on both surfaces.
##
## Read RESULT=, not the exit code.

## PUBLISHED [S]: Sierra Boat Company's 1934 Chris-Craft 27 ft Custom Runabout, model Custom 309.
const LENGTH: float = 8.230
const BEAM: float = 2.184
## Within 2 per cent of a published figure, as every model suite here is.
const TOLERANCE: float = 0.02

## The draft that must be deleted the day the simulation names a kind `runabout`.
const DRAFT := "res://objects/vehicles/ships/runabout_draft.gd"

## WHAT THE SIMULATION'S SHAPE TABLE CAN HOLD, from `merchant_models.gd`, which is the other suite that judges a shape
## before its kind exists. Typed rather than reached for: the two suites do not extend each other, and a `const` in a
## sibling is not in scope.
const MAX_PARTS: int = 24
const MAX_CORNERS: int = 8
const MAX_SEATS: int = 4

## HOW WIDE THE WATERLINE STRIPE MAY BE, metres, and how far from the waterline any of it may stray. The band is
## `ROWS`' spacing, which is 0.07 m; the window is generous enough that retuning the sections does not touch this
## check and tight enough that the 0.14 m band the first attempt drew fails it.
const STRIPE_WIDEST: float = 0.11
const STRIPE_STRAYS: float = 0.13
## How much of the boat's length the stripe must run along: it is a painted line from stem to transom, not a patch.
const STRIPE_RUNS: float = 0.70

## HOW FAR APART TWO COLOURS IN ONE MESH MUST BE, on some channel. `SurfaceTool.commit` quantises vertex colour to
## eight bits, and every suite here finds a part BY its colour (`modelling_here.md` section 6).
const COLOURS_APART: float = 0.03

## The colours the model declares, asked of it by name rather than copied, so a retint moves both together.
var _mahogany: Color = Runabout.MAHOGANY
var _stripe: Color = Runabout.STRIPE


func _check(label: String, ok: bool, detail: String) -> void:
	print("[runabout] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var geometry: Dictionary = _geometry()
	if geometry.is_empty():
		_check("the_runabout_has_a_shape", false, "neither a kind named runabout nor RunaboutDraft")
		_finish()
		return
	_the_draft_is_on_a_clock()
	_the_draft_fits_the_simulation(geometry)
	var made: Dictionary = ShipHull.models(-1, geometry)
	var ship: Node3D = ShipHull.dress(-1, geometry)
	add_child(ship)
	var near := made.get("near") as ArrayMesh
	_wound_outwards("runabout", made)
	_the_side_is_whole("runabout", geometry, _faces(near))
	_her_fittings_stand_on_what_is_drawn_under_them(made.get("fittings", []) as Array, near)
	_she_is_her_published_size(ship)
	_the_white_stripe_is_actually_drawn(near)
	_the_deck_is_the_same_wood_as_the_topsides(near)
	_every_colour_in_her_is_told_apart_from_every_other(near)
	_the_three_cockpits_are_open(geometry, near)
	_no_deck_plank_hangs_over_her_side(near)
	_she_is_low_poly(near)
	_finish()


## THE SHAPE, from the simulation if the kind exists and from the draft until it does, so this suite works on both
## sides of the C++ landing and needs no editing on the day it does.
func _geometry() -> Dictionary:
	for kind in range(int(Sim.kind_limits().get("kind_count", 0))):
		var shape: Dictionary = Sim.geometry_of(kind)
		if String(shape.get("name", "")) == "runabout":
			return shape
	if ResourceLoader.exists(DRAFT):
		return RunaboutDraft.geometry()
	return {}


## WHETHER THE GDSCRIPT COPY OF THE SHAPE IS STILL THERE AFTER THE KIND LANDED. One number in two places is one number
## in one place and a copy of it, and the copy is the one that goes stale.
func _the_draft_is_on_a_clock() -> void:
	var named: bool = false
	for kind in range(int(Sim.kind_limits().get("kind_count", 0))):
		named = named or String(Sim.geometry_of(kind).get("name", "")) == "runabout"
	var copy_left: bool = ResourceLoader.exists(DRAFT)
	_check("the_runabout_draft_is_deleted_once_the_kind_exists", not named or not copy_left,
		"no kind named runabout yet" if not named
			else "the kind exists and %s is still there: move the table into cockpit_world.cpp and delete it" % DRAFT)


## WHETHER THE SHAPE IS ONE THE C++ COULD HOLD: convex outlines, and inside the part, corner and seat counts.
func _the_draft_fits_the_simulation(geometry: Dictionary) -> void:
	var parts: Array = geometry.get("parts", []) as Array
	var widest: int = 0
	var bent: Array[String] = []
	for part in parts:
		var outline: PackedVector2Array = part["outline"]
		widest = maxi(widest, outline.size())
		var sign_seen: float = 0.0
		for i in range(outline.size()):
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[(i + 1) % outline.size()]
			var c: Vector2 = outline[(i + 2) % outline.size()]
			var turn: float = (b - a).cross(c - b)
			if absf(turn) < 0.0001:
				continue
			if sign_seen != 0.0 and signf(turn) != sign_seen:
				bent.append("%s at %s" % [String(part["part"]), b])
				break
			sign_seen = signf(turn)
	var seats: int = (geometry.get("seat_poses", []) as Array).size()
	_check("the_runabout_shape_is_one_the_simulation_could_hold",
		parts.size() <= MAX_PARTS and widest <= MAX_CORNERS and seats <= MAX_SEATS and bent.is_empty(),
		"%d parts of %d, %d corners of %d, %d seats of %d%s" % [parts.size(), MAX_PARTS, widest, MAX_CORNERS,
			seats, MAX_SEATS, "" if bent.is_empty() else ", outlines not convex: " + ", ".join(bent)])


## EVERY FITTING STANDS ON WHAT IS ACTUALLY DRAWN UNDER IT, which on this boat is a different question from the one
## `ship_models._fittings_stand_on_the_ship` asks -- and the difference is the finding, not an excuse.
##
## THAT CHECK'S DATUM IS A COLLISION PART'S FLAT TOP, and it is right for every ship in the game because every one of
## them has a flat deck. **This boat's drawn deck is not flat**: it carries 0.29 m of sheer at the stem and 0.028 m of
## camber, so her deck stands up to 0.29 m above the `deck` part whose top the shared check measures against, and
## every cleat on it reported "on nothing" while sitting exactly where it belongs. Her benches reported "inside a
## part" for the mirror-image reason -- a cockpit is a HOLE in the deck, so a bench in one is legitimately below deck
## level and inside the hull part's box, and the shared check has no concept of a well.
##
## SO THE DATUM MOVES TO THE DRAWN SURFACE, which is what a viewer sees a fitting sitting on and is therefore the
## stricter question, not the looser one: a cleat floating 0.1 m over the planking fails this and would have passed
## the shared one, because the shared one would have called it "on nothing" either way. Nothing outside this file
## changes, and no ship's check is weakened to let a boat through.
func _her_fittings_stand_on_what_is_drawn_under_them(fittings: Array, mesh: ArrayMesh) -> void:
	if fittings.is_empty():
		_check("her_fittings_stand_on_what_is_drawn_under_them", false, "her model reported no fittings")
		return
	var faces: Array = _coloured_faces(mesh)
	var wrong: Array[String] = []
	for item in fittings:
		var box := item as AABB
		var middle: Vector3 = box.get_center()
		var at := Vector2(middle.x, middle.z)
		var foot: float = box.position.y
		var under: float = -INF
		for face in faces:
			if face[4].y < 0.5:
				continue
			var y: float = (face[0].y + face[1].y + face[2].y) / 3.0
			# The surface it stands on is the highest up-facing thing at or just under its foot: anything above the
			# foot is the fitting itself, or something laid over it.
			if y > foot + FOOT:
				continue
			if _covers(face[0], face[1], face[2], at):
				under = maxf(under, y)
		if under == -INF or absf(foot - under) > FOOT:
			wrong.append("(%.2f, %.2f, %.2f) with %s under it" % [middle.x, foot, middle.z,
				"nothing drawn" if under == -INF else "%.2f m" % under])
	_check("her_fittings_stand_on_what_is_drawn_under_them", wrong.is_empty(),
		"%d fittings%s" % [fittings.size(), "" if wrong.is_empty() else ", standing on nothing: " + ", ".join(wrong)])


## HER LENGTH AND BEAM OFF THE DRAWN VERTICES, against the two figures a source actually prints. Measured from
## TRANSFORMED VERTICES and never from `transform * get_aabb()`, which grows every time a thing is turned
## (`modelling_here.md` section 6).
func _she_is_her_published_size(ship: Node3D) -> void:
	var box: AABB = _drawn_bounds(ship)
	for row in [["length", box.size.z, LENGTH], ["beam", box.size.x, BEAM]]:
		var drawn: float = float(row[1])
		var published: float = float(row[2])
		_check("her_drawn_%s_is_the_published_one" % String(row[0]),
			absf(drawn - published) <= published * TOLERANCE,
			"%.3f m drawn against %.3f m published, %.1f per cent"
				% [drawn, published, 100.0 * absf(drawn - published) / published])


## THE WHITE STRIPE: drawn at all, at the waterline, no wider than a boot-top, and running most of the boat. See the
## doc block -- this is the check the suite exists for.
func _the_white_stripe_is_actually_drawn(mesh: ArrayMesh) -> void:
	var low: float = INF
	var high: float = -INF
	var fore: float = INF
	var aft: float = -INF
	var found: int = 0
	for face in _coloured_faces(mesh):
		if not _same_colour(face[3], _stripe):
			continue
		found += 1
		for i in range(3):
			var p: Vector3 = face[i]
			low = minf(low, p.y)
			high = maxf(high, p.y)
			fore = minf(fore, p.z)
			aft = maxf(aft, p.z)
	if found == 0:
		_check("the_white_stripe_is_actually_drawn", false,
			"NO face is painted the stripe colour. HullLoft paints a row GAP by that gap's MIDPOINT, so sections that"
			+ " step over the waterline paint no stripe and the hull is not wrong -- see the doc block")
		return
	var wide: float = high - low
	var runs: float = (aft - fore) / LENGTH
	_check("the_white_stripe_is_actually_drawn",
		wide <= STRIPE_WIDEST and maxf(absf(high), absf(low)) <= STRIPE_STRAYS and runs >= STRIPE_RUNS,
		"%d faces, %.3f m wide (at most %.2f), from y %.3f to %.3f, running %.0f per cent of her length"
			% [found, wide, STRIPE_WIDEST, low, high, 100.0 * runs])


## THE DECK AND THE TOPSIDES ARE ONE COLOUR. The deck reads much lighter in every photograph because it faces the sky,
## and a model that draws it lighter has the light in it twice. Asked of the drawn faces by which way they point: some
## mahogany must face UP (the deck planking) and some must face OUTBOARD (the topside skin), and it must be the SAME
## mahogany.
func _the_deck_is_the_same_wood_as_the_topsides(mesh: ArrayMesh) -> void:
	var up: int = 0
	var out: int = 0
	var nearly: Array[String] = []
	for face in _coloured_faces(mesh):
		var tint: Color = face[3]
		var normal: Vector3 = face[4]
		if _same_colour(tint, _mahogany):
			if normal.y > 0.6:
				up += 1
			elif absf(normal.y) < 0.5:
				out += 1
			continue
		# A SECOND, NEARLY-MAHOGANY COLOUR IS THE FAULT THIS IS LOOKING FOR: a deck "warmed up" a little would sit
		# close to the topside's colour and nothing else here would notice.
		if _apart(tint, _mahogany) < 0.12 and not nearly.has(str(tint)):
			nearly.append(str(tint))
	_check("the_deck_is_the_same_wood_as_the_topsides", up > 0 and out > 0 and nearly.is_empty(),
		"%d mahogany faces up (the deck), %d outboard (the topsides)%s" % [up, out,
			"" if nearly.is_empty() else ", and a second near-mahogany: " + ", ".join(nearly)])


## EVERY DISTINCT COLOUR IN HER MESH TELLS ITSELF APART FROM EVERY OTHER, on some channel. Asked of ONE mesh and not
## across the fleet, because a mesh is where a check has to tell two parts apart and two colours in two boats have
## nothing to do with each other (`lane/roadfleet`, `modelling_here.md` section 6).
func _every_colour_in_her_is_told_apart_from_every_other(mesh: ArrayMesh) -> void:
	var seen: Array[Color] = []
	for face in _coloured_faces(mesh):
		var tint: Color = face[3]
		var already: bool = false
		for c in seen:
			already = already or _apart(c, tint) < 0.004
		if not already:
			seen.append(tint)
	var collisions: Array[String] = []
	for i in range(seen.size()):
		for j in range(i + 1, seen.size()):
			if _apart(seen[i], seen[j]) < COLOURS_APART:
				collisions.append("%s and %s" % [str(seen[i]), str(seen[j])])
	_check("every_colour_in_her_is_told_apart_from_every_other", collisions.is_empty() and seen.size() >= 6,
		"%d distinct colours%s" % [seen.size(),
			"" if collisions.is_empty() else ", too close: " + ", ".join(collisions)])


## THE THREE COCKPITS ARE HOLES AND NOT PAINT. A deck drawn straight over a cockpit would leave the boat looking
## identical from a distance and the crew inside the planking, and every dimension check would stay green.
func _the_three_cockpits_are_open(geometry: Dictionary, mesh: ArrayMesh) -> void:
	var faces: Array = _coloured_faces(mesh)
	var covered: Array[String] = []
	var wells: int = 0
	for part in (geometry.get("parts", []) as Array):
		if not part.has("cockpit"):
			continue
		wells += 1
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		var at: Vector2 = r.get_center()
		var sole: float = float(part["bottom"])
		var lip: float = float(part["top"])
		for face in faces:
			if face[4].y < 0.6:
				continue
			var y: float = (face[0].y + face[1].y + face[2].y) / 3.0
			# Anything up-facing between a hand above the sole and the coaming is a lid over the cockpit. The sole
			# itself, and the bench standing on it, are what the band's bottom leaves out.
			if y < sole + 0.55 or y > lip + 0.05:
				continue
			if _covers(face[0], face[1], face[2], at):
				covered.append("%s at y %.2f" % [String(part["cockpit"]), y])
				break
	_check("the_three_cockpits_are_open", wells == 3 and covered.is_empty(),
		"%d wells%s" % [wells, "" if covered.is_empty() else ", roofed over: " + ", ".join(covered)])


## NO DECK PLANK HANGS OVER HER SIDE. The deck's planks are laid by fraction between a king plank and a covering
## board, and where the boat is 0.03 m across at the stem there is no room for seven of them: the plank width clamps
## to its floor, the boundaries walk out past the covering board, and the forward planking is drawn WIDER THAN THE
## HULL IT SITS ON. It showed up first as faces wound backwards and was cured twice over -- once by clamping the
## boundaries and once, accidentally, by giving each deck triangle its own normal -- so the winding check no longer
## catches it and this one does. **A mutant that stops being caught has not gone away; it has moved.**
##
## Asked by comparing, band of stations by band of stations, the widest DECK-coloured face against the widest face of
## any kind there. The hull's own sheer is the widest thing at every station, so the comparison needs no table of the
## boat's plan and nothing typed: the model is held to itself, which is the one place that is allowed, because the
## question is whether two parts of it agree rather than whether either is right.
func _no_deck_plank_hangs_over_her_side(mesh: ArrayMesh) -> void:
	var bands: int = 40
	var hull := PackedFloat32Array()
	var deck := PackedFloat32Array()
	hull.resize(bands)
	deck.resize(bands)
	var faces: Array = _coloured_faces(mesh)
	for face in faces:
		var decking: bool = face[4].y > 0.6 and (_same_colour(face[3], _mahogany)
			or _same_colour(face[3], Runabout.SEAM) or _same_colour(face[3], Runabout.WALNUT))
		# THE HULL'S WIDTH COMES FROM ITS SKIN AND NOT FROM EVERYTHING DRAWN. Taking the widest face of any kind put
		# the DECK'S OWN overhanging planks into the figure the deck was then compared against, so the check compared
		# a number with itself and passed over the very mutant it was written for. The skin is what faces sideways.
		var skin: bool = absf(face[4].y) < 0.5
		for i in range(3):
			var p: Vector3 = face[i]
			var band: int = clampi(int((p.z / LENGTH + 0.5) * float(bands)), 0, bands - 1)
			if skin:
				hull[band] = maxf(hull[band], absf(p.x))
			if decking:
				deck[band] = maxf(deck[band], absf(p.x))
	var over: Array[String] = []
	for band in range(bands):
		if deck[band] <= 0.0:
			continue
		if deck[band] > hull[band] + 0.01:
			over.append("band %d: deck %.3f m over a hull %.3f m" % [band, deck[band], hull[band]])
	_check("no_deck_plank_hangs_over_her_side", over.is_empty(),
		"%d bands of stations%s" % [bands, "" if over.is_empty() else ", planking outboard of the hull: "
			+ ", ".join(over)])


## THE LOW-POLY LOOK, REPORTED RATHER THAN ONLY BOUNDED. The house style is faceted (the user, 2026-09-17) and the
## number is printed beside the fleet's others so the next reader can compare: the F/A-18F's exterior is 1,700
## triangles and the launch's near model 11,466.
func _she_is_low_poly(mesh: ArrayMesh) -> void:
	var total: int = 0
	for s in range(mesh.get_surface_count()):
		total += _triangles(mesh, s)
	_check("her_near_model_is_inside_the_first_lod_budget", total > 0 and total <= NEAR_TRIANGLES,
		"%d triangles in %d surfaces, against a budget of %d (the launch is 11,466, the F/A-18F's exterior 1,700)"
			% [total, mesh.get_surface_count(), NEAR_TRIANGLES])


## THE NEAR MODEL AS `[a, b, c, colour, normal]`. `ship_models._faces` drops the colour, and on this boat the colour is
## how a check knows a plank from a seam from the bottom paint.
func _coloured_faces(mesh: ArrayMesh) -> Array:
	var out: Array = []
	if mesh == null:
		return out
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if colours.size() < points.size():
			continue
		for i in range(0, points.size() - 2, 3):
			out.append([points[i], points[i + 1], points[i + 2], colours[i], normals[i]])
	return out


## EVERY DRAWN VERTEX'S BOUNDS IN THE SHIP'S OWN FRAME. `fighter.gd:_drawn_bounds` is the original; it is copied here
## rather than reached for, because `ship_models` does not carry one.
func _drawn_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var started: bool = false
	for drawn in root.find_children("*", "MeshInstance3D", true, false):
		var instance := drawn as MeshInstance3D
		if instance.mesh == null or instance.visibility_range_begin > 0.0:
			continue
		var into: Transform3D = root.global_transform.affine_inverse() * instance.global_transform
		for s in range(instance.mesh.get_surface_count()):
			for p in (instance.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var at: Vector3 = into * p
				if not started:
					box = AABB(at, Vector3.ZERO)
					started = true
				else:
					box = box.expand(at)
	return box


## HOW FAR APART TWO COLOURS ARE: the widest of the three channel differences, which is the question
## `SurfaceTool.commit`'s eight-bit quantisation actually asks.
func _apart(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _same_colour(a: Color, b: Color) -> bool:
	return _apart(a, b) < 0.01
