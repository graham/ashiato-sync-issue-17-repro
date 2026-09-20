class_name StainSheet
extends RefCounted

## A SHEET OF DIRT FOR ONE AIRCRAFT: named, placed stains baked into one RGBA image that a material carries as its
## DETAIL layer on UV2. It is a physical object -- a sheet of grime with a list of marks on it -- and not a
## `Weathering` process, which is why it owns the marks and hands out an `Image` rather than doing something to a
## mesh.
##
## WHY A DETAIL LAYER AND NOT AN `albedo_texture`. The detail layer's ALPHA decides where the mark lands, so where
## alpha is zero the paint underneath is untouched, and a mark may be LIGHTER as well as darker -- sun fade and
## bare metal both go the wrong way under a multiply. This was not taken on trust: `tests/detail_probe.gd` renders
## it and reads the pixels back, because nothing in this workshop had ever used `detail_*` on any material.
##
## THE MARKS ARE PLACED IN METRES, NOT IN UV. A stain says "station 14.5 to 19.2, 0.9 to 2.2 m over the ground, on
## the sides", and this class turns that into pixels. Written the other way round -- as `u` and `v` in 0..1 -- every
## number in the list would have to be recomputed by hand the first time the sheet changed size or the aeroplane's
## length was corrected, and the list would stop being readable against a photograph. It also means a test can ask
## `intensity_at` about a REAL vertex of the drawn mesh.
##
## ONE MAPPING, USED BY BOTH SIDES. `uv2_for` is what the airframe writes into `ARRAY_TEX_UV2` and what `image`
## rasterises through, so the picture and the geometry cannot drift apart. That is the "one number, one place" rule
## applied to a projection: if this function is wrong, it is wrong in both places at once and a test sees it.
##
## THE PROJECTION IS FOUR BANDS IN ONE SHEET, chosen by the face normal the builder already computed:
##
##   v 0.00 - 0.50   SIDE faces      (station, height over the ground)
##   v 0.50 - 0.75   UP faces        (station, distance from the centreline)
##   v 0.75 - 1.00   DOWN faces      (station, distance from the centreline)
##
## The step 0 plan put up and down in ONE band. They are split here because they share every texel otherwise, and
## walkway wear scuffed onto the top of the wing root would have appeared, identically, on its underside -- which no
## aeroplane has and every picture would show. It is the same mechanism and one extra line; nothing else moved.
##
## WHAT IT IS NOT: a noise field. Eight named marks a person can argue with beat a procedural smudge nobody can
## check, and only a named mark can be asserted by a test or moved by a mutant.

## Which band of the sheet a face reads, decided by its normal.
enum Face { SIDE, UP, DOWN }

## A face counts as UP or DOWN rather than SIDE once its normal is more vertical than this. A cosine, so 0.5 is
## sixty degrees off the horizontal -- the Phantom's fuselage sides are near-vertical and its wings near-horizontal,
## and the slabby bits in between read better as sides.
const VERTICAL: float = 0.5

## How far outside a mark's own box the fade reaches, as a share of the box. A hard edge reads as a decal.
const FEATHER: float = 0.45

## The aeroplane this sheet is cut for: overall length, the height of its tallest point over the ground, and its
## half span. Metres.
var length: float = 1.0
var tall: float = 1.0
var half_span: float = 1.0

## The marks, in the order they are laid down. Each is a Dictionary; see `mark`.
var marks: Array[Dictionary] = []


func _init(aircraft_length: float = 1.0, aircraft_tall: float = 1.0, aircraft_half_span: float = 1.0) -> void:
	length = maxf(aircraft_length, 0.001)
	tall = maxf(aircraft_tall, 0.001)
	half_span = maxf(aircraft_half_span, 0.001)


## ONE NAMED MARK, in metres. `from_station`/`to_station` run aft from the nose. `from_across`/`to_across` are
## metres over the ground on a SIDE face and metres from the centreline on an UP or DOWN face -- the second axis of
## whichever band the mark is on, which is why one pair of numbers serves both.
##
## `faces` IS A LIST, not one band. Soot leaving one engine lands on the side of the fuselage AND on its belly;
## as two marks that would be two names for one piece of dirt and two places to edit when it moves. Eight named
## marks was the design and eight is what there are.
##
## `every` AND `wide` MAKE A MARK REPEAT along the station axis -- a band `wide` metres across, once `every`
## metres, within the overall station range. `panel_line_dirt` is the reason they exist. Written as ONE box
## spanning the whole aeroplane it was not panel lines at all, it was a flat veil over every texel of the sheet:
## a measured 100% coverage at a mean alpha of 0.175, which dirtied the radome as much as the tailpipe and made
## the whole aeroplane uniformly grubby and nothing on it legible. Grime gathers AT the joins and the paint
## between them stays paint; a stain sheet with no clean paint on it has nothing to be dirty against.
##
## `strength` is how much of the mark's colour lands at its centre, 0 to 1, and it is the ALPHA: a mark at 0.35
## leaves nearly two thirds of the paint showing through. `colour` darker than the paint dirties it and lighter
## fades it; both are ordinary colours here because the alpha, not the colour, is what makes a mark a mark.
func mark(name: String, faces: Array, from_station: float, to_station: float,
		from_across: float, to_across: float, colour: Color, strength: float,
		every: float = 0.0, wide: float = 0.0) -> void:
	marks.append({
		"name": name, "faces": faces,
		"station": Vector2(minf(from_station, to_station), maxf(from_station, to_station)),
		"across": Vector2(minf(from_across, to_across), maxf(from_across, to_across)),
		"colour": colour, "strength": clampf(strength, 0.0, 1.0),
		"every": maxf(every, 0.0), "wide": maxf(wide, 0.0),
	})


## WHICH BAND A NORMAL READS. Public because the airframe asks it per face and a test asks it per claim.
static func face_for(normal: Vector3) -> Face:
	if normal.y > VERTICAL:
		return Face.UP
	if normal.y < -VERTICAL:
		return Face.DOWN
	return Face.SIDE


## THE UV2 OF ONE VERTEX. `station` is metres aft of the nose, `height` metres over the ground and `across` metres
## from the centreline (either side -- a mark is symmetric, because an aeroplane's dirt broadly is and one sheet
## then serves both sides).
func uv2_for(face: Face, station_m: float, height_m: float, across_m: float) -> Vector2:
	var u: float = clampf(station_m / length, 0.0, 1.0)
	match face:
		Face.UP:
			return Vector2(u, 0.50 + 0.25 * clampf(absf(across_m) / half_span, 0.0, 1.0))
		Face.DOWN:
			return Vector2(u, 0.75 + 0.25 * clampf(absf(across_m) / half_span, 0.0, 1.0))
		_:
			return Vector2(u, 0.50 * clampf(height_m / tall, 0.0, 1.0))


## HOW DIRTY ONE PLACE ON THE AEROPLANE IS, 0 to 1 -- the alpha that will land there. A pure function of the marks,
## so a test can call it without rendering anything and a mutant that moves a mark changes it.
##
## The marks COMPOUND rather than add: two marks at 0.5 leave a quarter of the paint, not none. Adding them would
## saturate to flat black wherever two overlap, which is exactly where the interesting dirt is.
func intensity_at(face: Face, station_m: float, height_m: float, across_m: float) -> float:
	var clean: float = 1.0
	for m in marks:
		clean *= 1.0 - _falloff(m, face, station_m, height_m, across_m) * float(m["strength"])
	return 1.0 - clean


## THE COLOUR AND ALPHA at one place: the marks' colours weighted by how strongly each lands, with `intensity_at`'s
## alpha. Returned together because a caller that has one always wants the other.
func sample(face: Face, station_m: float, height_m: float, across_m: float) -> Color:
	var weight: float = 0.0
	var mixed := Vector3.ZERO
	for m in marks:
		var f: float = _falloff(m, face, station_m, height_m, across_m) * float(m["strength"])
		if f <= 0.0:
			continue
		var c: Color = m["colour"]
		mixed += Vector3(c.r, c.g, c.b) * f
		weight += f
	var alpha: float = intensity_at(face, station_m, height_m, across_m)
	if weight <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	mixed /= weight
	return Color(mixed.x, mixed.y, mixed.z, alpha)


## THE WHOLE SHEET, baked. Every texel is the same arithmetic `intensity_at` and `sample` do, so the image cannot
## disagree with what a test is told -- but it is done in ONE PASS over the marks here instead of two.
##
## IT IS WORTH THE DUPLICATION AND THE MEASUREMENT SAYS SO. Written as a loop calling `sample`, which itself calls
## `intensity_at`, this walked the mark list TWICE for each of 131,072 texels and took **2,951 ms** -- so dressing
## an F-4 cost three seconds against 6.9 ms for one with no weathering, every time one was built. Nothing failed:
## no suite times an airframe, and the cost only reached the world when the kind got its `Terrain.spawns` row, where
## it showed up as `no_vr_flight` timing out with no error printed.
func image(wide: int = 512, high: int = 256) -> Image:
	var made := Image.create(wide, high, false, Image.FORMAT_RGBA8)
	for y in range(high):
		var v: float = (float(y) + 0.5) / float(high)
		var face: Face = Face.SIDE
		var across_fraction: float = 0.0
		var height_fraction: float = 0.0
		if v < 0.50:
			height_fraction = v / 0.50
		elif v < 0.75:
			face = Face.UP
			across_fraction = (v - 0.50) / 0.25
		else:
			face = Face.DOWN
			across_fraction = (v - 0.75) / 0.25
		# THE MARKS THAT COULD REACH THIS ROW AT ALL, worked out once for the row rather than once a texel: a mark
		# is on one set of bands and one band of height or offset, and most rows see two or three of the eight.
		var second: float = (across_fraction * half_span) if face != Face.SIDE else (height_fraction * tall)
		var here: Array[Dictionary] = []
		for m in marks:
			if m["faces"].has(face) and _band(m["across"], second) > 0.0:
				here.append(m)
		if here.is_empty():
			continue
		for x in range(wide):
			var station_m: float = ((float(x) + 0.5) / float(wide)) * length
			var clean: float = 1.0
			var weight: float = 0.0
			var mixed := Vector3.ZERO
			for m in here:
				var f: float = _falloff(m, face, station_m, height_fraction * tall,
					across_fraction * half_span) * float(m["strength"])
				if f <= 0.0:
					continue
				clean *= 1.0 - f
				var c: Color = m["colour"]
				mixed += Vector3(c.r, c.g, c.b) * f
				weight += f
			if weight <= 0.0:
				continue
			mixed /= weight
			made.set_pixel(x, y, Color(mixed.x, mixed.y, mixed.z, 1.0 - clean))
	return made

## HOW STRONGLY ONE MARK LANDS at a place, 0 to 1: 1 inside its box, fading to 0 across `FEATHER` of the box's own
## size outside it, and 0 on a face the mark is not on.
func _falloff(m: Dictionary, face: Face, station_m: float, height_m: float, across_m: float) -> float:
	if not m["faces"].has(face):
		return 0.0
	var second: float = absf(across_m) if face != Face.SIDE else height_m
	var along: float = _band(m["station"], station_m)
	var every: float = float(m["every"])
	if every > 0.0:
		# INSIDE the overall run, the mark is a narrow band once every `every` metres. Outside it, nothing --
		# so `along` still gates the whole thing and a repeating mark cannot leak past its own ends.
		var span: Vector2 = m["station"]
		if station_m < span.x or station_m > span.y:
			return 0.0
		var phase: float = fmod(station_m - span.x, every)
		var wide: float = maxf(float(m["wide"]), 0.01)
		along = _band(Vector2(0.0, wide), phase)
	return along * _band(m["across"], second)


## ONE AXIS OF THE FADE. `span` is the mark's low and high edge on that axis.
static func _band(span: Vector2, at: float) -> float:
	var half: float = maxf((span.y - span.x) * 0.5, 0.0001)
	var edge: float = maxf(half * FEATHER, 0.0001)
	var from_centre: float = absf(at - (span.x + span.y) * 0.5)
	if from_centre <= half:
		return 1.0
	return clampf(1.0 - (from_centre - half) / edge, 0.0, 1.0)
