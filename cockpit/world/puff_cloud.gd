extends RefCounted
class_name PuffCloud
## A CLOUD MADE OF PUFFS: transparent ellipsoids of air, each drawn by `world/shaders/puff.gdshader` as the optical depth of
## its own chord, laid out as one of six kinds at the height that kind lives at. A PROTOTYPE (lane/clouds2, 2026-09-17),
## asked for by the user: "perhaps transparent spheres in the right orientation will feel like clouds, i'd like to have more
## variations on clouds and have them at different altitudes so planes can fly through, around them." It stands beside
## `LiftYard`'s cumulus and replaces nothing until the user chooses; research/clouds_2.md has the reasoning.
##
## THE DECISION: EVERY SHAPE IS A FUNCTION OF ITS SEED, static and pure, so the drawing, the tests and every peer lay the
## same cloud out from the same numbers -- the host needs only to hand out the plan's seed. Every number a kind is shaped
## by is in its row of `KINDS`, and every height is in its `band`: nothing about a kind is typed twice.
##
## WHAT WENT WRONG BEFORE, and why these are not LiftYard's lumps: a lump was an opaque sphere with a blended rim, so every
## lump had a skin, a heap of them read as balls up close, and from inside one the island was in plain view (agents.md, "A
## cloud you can fly into"). A puff has no skin: its density falls to nothing at its edge, overlapping puffs add up as one
## volume in any order, and the eye inside one sees through the depth of cloud in front of it.

## Kinds, one row each. `band` the heights its base is drawn between, `density` its core's optical depth a metre, `shade`
## how dark its base is lit (0 white, 1 darkest), `firm` how hard its puffs' edges are, `noise_cell` the metres a noise cell
## (and so a lobe). The shape numbers are each kind's own; see its function below.
##
## THE LOOK, as the user tunes it from pictures (clouds3, 2026-09-18; world/shaders/puff.gdshaderinc says what each does):
## `crisp` how wide the outline's fade is (0.02 cut, 0.3 smoke), `bump` how deep the lobes bite into the outline, `relief`
## how steeply the lobes stand to the light, `body` how much more solid the cloud reads from outside than its depth makes it,
## `shade_light` how bright the blue-grey shaded side is against the sunlit one, `terminator` how soft the line between them
## is, `top` how much brighter the sunlit crown is than the foot. Every row names every one: nothing falls back to a default.
const KINDS: Dictionary = {
	"cumulus": {"under": "stratocumulus", "band": Vector2(1000.0, 1400.0), "width": Vector2(450.0, 800.0), "tall": Vector2(0.40, 0.60),
		"puffs": Vector2i(10, 16), "density": 0.012, "shade": 0.35, "firm": 0.0, "noise_cell": 70.0,
		"crisp": 0.07, "bump": 0.22, "relief": 0.6, "body": 3.0, "shade_light": 0.45, "terminator": 0.22, "top": 1.3},
	"towering": {"band": Vector2(1100.0, 1400.0), "width": Vector2(1400.0, 1900.0), "tall": Vector2(1.3, 1.7),
		"puffs": Vector2i(5, 7), "density": 0.014, "shade": 0.8, "firm": 0.15, "noise_cell": 110.0,
		"crisp": 0.05, "bump": 0.25, "relief": 0.7, "body": 4.0, "shade_light": 0.4, "terminator": 0.18, "top": 1.4},
	"flat_based": {"under": "stratocumulus", "band": Vector2(1200.0, 1500.0), "width": Vector2(900.0, 1300.0), "tall": Vector2(0.55, 0.75),
		"puffs": Vector2i(16, 22), "density": 0.014, "shade": 0.75, "firm": 0.1, "noise_cell": 90.0,
		"crisp": 0.06, "bump": 0.22, "relief": 0.6, "body": 3.5, "shade_light": 0.4, "terminator": 0.2, "top": 1.35},
	"stratocumulus": {"layer": true, "under": "altocumulus", "band": Vector2(2200.0, 2500.0), "width": Vector2(4500.0, 6000.0), "tall": Vector2(280.0, 360.0),
		"puffs": Vector2i(0, 0), "cell": 420.0, "spread": Vector2(0.7, 1.05), "cover": 0.62, "density": 0.009, "shade": 0.55, "firm": 0.0,
		"noise_cell": 120.0,
		"crisp": 0.15, "bump": 0.2, "relief": 0.5, "body": 1.8, "shade_light": 0.52, "terminator": 0.35, "top": 1.15},
	"altocumulus": {"layer": true, "under": "cirrus", "band": Vector2(4200.0, 4800.0), "width": Vector2(3500.0, 4500.0), "tall": Vector2(110.0, 150.0),
		"puffs": Vector2i(0, 0), "cell": 170.0, "spread": Vector2(1.15, 1.45), "cover": 0.55, "density": 0.012, "shade": 0.3, "firm": 0.0,
		"noise_cell": 90.0,
		"crisp": 0.4, "bump": 0.0, "relief": 0.2, "body": 1.0, "shade_light": 0.58, "terminator": 0.5, "top": 1.15},
	"cirrus": {"layer": true, "band": Vector2(8200.0, 9400.0), "width": Vector2(5000.0, 7000.0), "tall": Vector2(60.0, 90.0),
		"puffs": Vector2i(14, 20), "density": 0.0035, "shade": 0.0, "firm": 0.0, "noise_cell": 260.0,
		"crisp": 0.35, "bump": 0.0, "relief": 0.2, "body": 1.0, "shade_light": 0.9, "terminator": 0.6, "top": 1.0},
}

## How far a cloud's base stands over the highest ground under it, at the least.
const CLEARANCE: float = 250.0
## THE CLEAR AIR BETWEEN TWO LAYERS, at the least: a kind with an `under` keeps its top this far below the lowest base that
## kind's band allows, so an aeroplane can always fly between the decks. Found by tests/puff_sky.gd, not by looking: the
## largest flat-based heaps topped out at 2,208 m, into the stratocumulus band's 2,200. Over high ground a cloud is lifted
## to clear it, and may then stand in the layer above; the ground wins.
const CLEAR_AIR: float = 300.0
## A TOWER'S MASSES: their radius as a share of half its width at the foot and at the top, and how many lobes each has.
const TOWER_FOOT: float = 0.9
const TOWER_NECK: float = 0.6
const TOWER_LOBES := Vector2i(3, 5)
## The least a heap is squashed to under the layer above; a cloud with less room than this is left its own height.
const LEAST_TALL: float = 150.0


## ONE CLOUD OF `kind`, its footprint centred over `at` (x and z; y is ignored), its base drawn from the kind's band from
## `seed`, lifted where it must be to clear the ground under every puff by CLEARANCE. `ground` answers the height of the
## ground under a world point (Callable(Vector3) -> float); an empty Callable is flat ground at 0. `shape` may name the
## cloud's own "base" (a world height, in place of the band's) and "width" (metres, in place of the row's range): a thermal's
## cloud stands at its column's top and is as wide as its column spreads (`PuffSky.thermal_clouds`).
## Returns {kind, base, thickness, seed, density, puffs}, each puff {centre, radii, yaw}.
static func lay_out(kind: String, at: Vector3, seed: int, ground: Callable = Callable(), shape: Dictionary = {}) -> Dictionary:
	var row: Dictionary = KINDS[kind]
	if shape.has("width"):
		row = row.duplicate()
		row["width"] = Vector2(float(shape["width"]), float(shape["width"]))
	var dice := RandomNumberGenerator.new()
	dice.seed = seed
	var band: Vector2 = row["band"]
	var base: float = dice.randf_range(band.x, band.y)
	if shape.has("base"):
		base = float(shape["base"])
	var puffs: Array[Dictionary] = []
	var thickness := 0.0
	match kind:
		"cumulus", "flat_based":
			thickness = _heap(dice, row, puffs)
		"towering":
			thickness = _tower(dice, row, puffs)
		"stratocumulus", "altocumulus":
			thickness = _sheet(dice, row, puffs, kind == "altocumulus")
		"cirrus":
			thickness = _streaks(dice, row, puffs)
	# UNDER THE NEXT LAYER: squash the cloud towards its base until its top clears the layer above by CLEAR_AIR.
	if row.has("under"):
		var room: float = float(KINDS[row["under"]]["band"].x) - CLEAR_AIR - base
		var top := 0.0
		for puff in puffs:
			top = maxf(top, (puff["centre"] as Vector3).y + (puff["radii"] as Vector3).y)
		# A cloud whose base is already near the layer above -- a thermal topping out high over a mountain -- keeps its
		# shape: squashing it to nothing would lose the thermal's mark, and the ground wins over the layers.
		if top > room and room >= LEAST_TALL:
			var squash := room / top
			for puff in puffs:
				var c: Vector3 = puff["centre"]
				var r: Vector3 = puff["radii"]
				puff["centre"] = Vector3(c.x, c.y * squash, c.z)
				puff["radii"] = Vector3(r.x, r.y * squash, r.z)
			thickness *= squash
	# The puffs were laid out about a base at 0 over (0, 0): stand them over `at`, on a base that clears the ground.
	var lowest := base
	if ground.is_valid():
		var highest := -INF
		for puff in puffs:
			var c: Vector3 = puff["centre"]
			var r: Vector3 = puff["radii"]
			for corner in [Vector3.ZERO, Vector3(r.x, 0, 0), Vector3(-r.x, 0, 0), Vector3(0, 0, r.z), Vector3(0, 0, -r.z)]:
				var under: Vector3 = Vector3(at.x, 0.0, at.z) + Vector3(c.x, 0.0, c.z) + _turned(corner, puff["yaw"])
				highest = maxf(highest, float(ground.call(under)))
		lowest = maxf(base, highest + CLEARANCE)
	for puff in puffs:
		puff["centre"] = (puff["centre"] as Vector3) + Vector3(at.x, lowest, at.z)
	return {"kind": kind, "base": lowest, "thickness": thickness, "seed": seed, "density": row["density"],
		"puffs": puffs}


## A HEAP: a cumulus, or a flat-based one. A core on the base, puffs piled on it smaller as they climb, and a skirt. The
## puffs' centres sit a little under their own tops so the flat base (the shader's cut) has body right down to it.
static func _heap(dice: RandomNumberGenerator, row: Dictionary, puffs: Array[Dictionary]) -> float:
	var width: float = dice.randf_range(row["width"].x, row["width"].y)
	var tall: float = width * dice.randf_range(row["tall"].x, row["tall"].y)
	var count: int = dice.randi_range(row["puffs"].x, row["puffs"].y)
	var long := dice.randf_range(1.0, 1.5)
	var heading := dice.randf() * TAU
	puffs.append({"centre": Vector3(0.0, tall * 0.25, 0.0), "radii": Vector3(width * 0.36 * long, tall * 0.55, width * 0.36),
		"yaw": heading})
	for p in range(count - 1):
		var up := pow(dice.randf(), 1.3)
		var reach := (1.0 - up * 0.7) * width * 0.42
		var angle := dice.randf() * TAU
		var out := dice.randf_range(0.25, 1.0) * reach
		var size := width * dice.randf_range(0.13, 0.26) * (1.0 - up * 0.45)
		var local := Vector3(cos(angle) * out * long, up * tall * 0.8 + size * 0.2, sin(angle) * out)
		puffs.append({"centre": _turned(local, heading), "radii": Vector3(size, size * dice.randf_range(0.75, 1.0), size),
			"yaw": dice.randf() * TAU})
	return tall


## A TOWERING CUMULUS: billowing MASSES (`puffs` is how many) climbing a sheared column, each a big puff with lobes bulging
## out of it at random heights and angles, the masses overlapping by half so the column has no waist between them, and a
## cauliflower crown of small puffs on the top one. The first try stacked one puff a step at a random angle and read as a
## corkscrew of beads (cockpit-clouds2-02, 2026-09-17); the second, tiers of a ring of puffs each at one height, read up
## close as a stack of pancakes, and the user asked for "fuller billowing masses" (clouds3, 2026-09-18).
static func _tower(dice: RandomNumberGenerator, row: Dictionary, puffs: Array[Dictionary]) -> float:
	var width: float = dice.randf_range(row["width"].x, row["width"].y)
	var tall: float = width * dice.randf_range(row["tall"].x, row["tall"].y)
	var masses: int = dice.randi_range(row["puffs"].x, row["puffs"].y)
	var shear := Vector3(dice.randf_range(-0.15, 0.15), 0.0, dice.randf_range(-0.15, 0.15))
	var top_mass := Vector3.ZERO
	var top_size := 0.0
	for m in range(masses):
		var up := float(m) / float(masses - 1)
		# The mass's radius: widest at the foot, narrowing up the column, and a little wider again at the crown.
		var size := width * 0.5 * lerpf(TOWER_FOOT, TOWER_NECK, up) * dice.randf_range(0.9, 1.1)
		if up > 0.8:
			size *= 1.15
		var y := up * (tall - size * 0.85) + size * 0.5
		var middle := shear * y + Vector3(dice.randf_range(-0.12, 0.12), 0.0, dice.randf_range(-0.12, 0.12)) * size
		var core := middle + Vector3(0.0, y, 0.0)
		puffs.append({"centre": core, "radii": Vector3(size, size * dice.randf_range(0.8, 0.95), size),
			"yaw": dice.randf() * TAU})
		for l in range(dice.randi_range(TOWER_LOBES.x, TOWER_LOBES.y)):
			var angle := dice.randf() * TAU
			var out := size * dice.randf_range(0.6, 0.9)
			var lobe := size * dice.randf_range(0.45, 0.75)
			puffs.append({"centre": core + Vector3(cos(angle) * out, size * dice.randf_range(-0.35, 0.45), sin(angle) * out),
				"radii": Vector3(lobe, lobe * dice.randf_range(0.8, 1.0), lobe), "yaw": dice.randf() * TAU})
		top_mass = core
		top_size = size
	# THE CROWN: small puffs over the top mass's upper half, so the head is cauliflower rather than one dome.
	for c in range(dice.randi_range(4, 6)):
		var angle := dice.randf() * TAU
		var tilt := dice.randf_range(0.25, 0.9)
		var small := top_size * dice.randf_range(0.35, 0.55)
		var way := Vector3(cos(angle) * cos(tilt), sin(tilt), sin(angle) * cos(tilt))
		puffs.append({"centre": top_mass + way * top_size * 0.6, "radii": Vector3(small, small * 0.9, small),
			"yaw": dice.randf() * TAU})
	return tall


## A SHEET: stratocumulus or altocumulus. A jittered grid over the sheet's width, each cell holding a puff where a smooth
## cover field says there is cloud, so the sheet has broad gaps and not a salt of holes; altocumulus lies in rows.
static func _sheet(dice: RandomNumberGenerator, row: Dictionary, puffs: Array[Dictionary], rows: bool) -> float:
	var width: float = dice.randf_range(row["width"].x, row["width"].y)
	var tall: float = dice.randf_range(row["tall"].x, row["tall"].y)
	var cell: float = row["cell"]
	var cover: float = row["cover"]
	var cells := int(width / cell)
	var heading := dice.randf() * TAU
	var phase := Vector2(dice.randf() * 100.0, dice.randf() * 100.0)
	for i in range(cells):
		for j in range(cells):
			var x := (float(i) - cells * 0.5 + dice.randf_range(-0.35, 0.35)) * cell
			var z := (float(j) - cells * 0.5 + dice.randf_range(-0.35, 0.35)) * cell
			var here := _cover(Vector2(x, z) / (cell * 5.0) + phase)
			if rows:
				here = here * 0.6 + 0.4 * (0.5 + 0.5 * sin(z / cell * PI * 0.9))
			var edge := clampf(1.0 - Vector2(x, z).length() / (width * 0.5), 0.0, 1.0)
			if here * smoothstep(0.0, 0.3, edge) < 1.0 - cover:
				continue
			# `spread`: a puff's width in cells. Altocumulus at clouds2's 0.7 to 1.05, a puff to a cell with gaps between, read
			# from the flight level as bubble wrap (clouds3, step 4); at 1.15 to 1.45 its puffs overlap into soft rolls. OVERDRAW
			# goes as spread squared: under the deck looking up, clouds2's spread cost 0.103 / 0.280 ms (1600x900 / 2880x1620),
			# 1.15 to 1.45 costs 0.173 / 0.492, and 1.4 to 2.0, a little softer still, 0.256 / 0.744 -- measured in one hold.
			var size := cell * dice.randf_range(row["spread"].x, row["spread"].y)
			puffs.append({"centre": _turned(Vector3(x, tall * 0.35, z), heading),
				"radii": Vector3(size, tall * dice.randf_range(0.5, 0.75), size * dice.randf_range(0.8, 1.2)),
				"yaw": dice.randf() * TAU})
	return tall


## CIRRUS: long thin streaks all lying one way, each a chain of stretched puffs that curls up at one end (a hook).
static func _streaks(dice: RandomNumberGenerator, row: Dictionary, puffs: Array[Dictionary]) -> float:
	var width: float = dice.randf_range(row["width"].x, row["width"].y)
	var tall: float = dice.randf_range(row["tall"].x, row["tall"].y)
	var count: int = dice.randi_range(row["puffs"].x, row["puffs"].y)
	var along := dice.randf() * TAU
	for s in range(count):
		var start := Vector3(dice.randf_range(-0.5, 0.5) * width, 0.0, dice.randf_range(-0.5, 0.5) * width)
		var links := dice.randi_range(4, 7)
		var length := dice.randf_range(300.0, 600.0)
		var bend := dice.randf_range(-0.25, 0.25)
		var here := Vector3.ZERO
		var heading := along + dice.randf_range(-0.15, 0.15)
		for l in range(links):
			var hook := float(l) / float(links - 1)
			heading += bend / float(links)
			var step := Vector3(cos(heading), 0.0, sin(heading)) * length * 0.7
			here += step
			var fat := lerpf(1.0, 0.5, hook)
			puffs.append({"centre": start + here + Vector3(0.0, tall * (0.5 + hook * hook * 1.5), 0.0),
				"radii": Vector3(length * fat, tall * 0.6 * fat, dice.randf_range(150.0, 320.0) * fat),
				"yaw": -heading})
	return tall * 2.5


## A smooth 0-to-1 field for where a sheet has cloud: two octaves of value noise from the same hash `Terrain` uses.
static func _cover(p: Vector2) -> float:
	return _value(p) * 0.65 + _value(p * 2.1 + Vector2(7.3, 1.9)) * 0.35


static func _value(p: Vector2) -> float:
	var cell := p.floor()
	var f := p - cell
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash(cell)
	var b := _hash(cell + Vector2(1, 0))
	var c := _hash(cell + Vector2(0, 1))
	var d := _hash(cell + Vector2(1, 1))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _hash(cell: Vector2) -> float:
	var h := int(cell.x) * 73856093 ^ int(cell.y) * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xFFFF) / 65535.0


static func _turned(v: Vector3, yaw: float) -> Vector3:
	return Vector3(v.x * cos(yaw) + v.z * sin(yaw), v.y, -v.x * sin(yaw) + v.z * cos(yaw))


## THE TRANSFORM A PUFF IS DRAWN WITH: the unit sphere scaled to its radii and turned about the vertical by its yaw.
## Only a vertical turn, so the shader can carry the cloud's flat base into the puff's own space through the y scale.
static func puff_transform(puff: Dictionary) -> Transform3D:
	var basis := Basis(Vector3.UP, float(puff["yaw"])).scaled_local(puff["radii"])
	return Transform3D(basis, puff["centre"])


## THE MIDDLE OF A CLOUD'S PUFFS, and how far its farthest puff's edge lies from there: what the shader lights it as.
static func middle_of(cloud: Dictionary) -> Vector3:
	var sum := Vector3.ZERO
	for puff in cloud["puffs"]:
		sum += puff["centre"]
	return sum / float(maxi((cloud["puffs"] as Array).size(), 1))


static func reach_of(cloud: Dictionary) -> float:
	var middle := middle_of(cloud)
	var most := 1.0
	for puff in cloud["puffs"]:
		var radii: Vector3 = puff["radii"]
		most = maxf(most, ((puff["centre"] as Vector3) - middle).length() + maxf(radii.x, maxf(radii.y, radii.z)))
	return most


## HOW MUCH CLOUD IS AT `point`, per metre: the sum over `cloud`'s puffs of the shader's own density, core density times
## (1 - r^2) in the puff's unit sphere, above the cloud's base. The same profile the picture is drawn with, noise at its
## mean, so "the eye is in a cloud" begins where the picture does.
static func density_at(cloud: Dictionary, point: Vector3) -> float:
	if point.y < float(cloud["base"]):
		return 0.0
	var sum := 0.0
	for puff in cloud["puffs"]:
		var local: Vector3 = puff_transform(puff).affine_inverse() * point
		var r2 := local.length_squared()
		if r2 < 1.0:
			sum += (1.0 - r2)
	return sum * float(cloud["density"])
