@tool
extends RefCounted
class_name Battleship
## AN IOWA, UP CLOSE: the battleship's own model -- three triple 16-inch turrets, the six 5-inch mounts the 1980s refit
## kept, the Tomahawk and Harpoon launchers, four Phalanx mounts, a teak deck and the helicopter pad on the fantail --
## welded into one mesh on top of what `Superstructure` builds from the parts.
##
## Its hull, decks, superstructure and pilot house are parts in the simulation's shape table (`battleship_shape`, step 3
## of the carrier lane). This adds what nothing collides with, from the boat research (research-boats.md in the carrier
## lane's drafts, 2026-09-15), each place marked with how sure the sheet is.
##
## EVERY FITTING STANDS ON THE PART UNDER IT (`Superstructure.top_under`), and none is typed a height. The first draft
## typed the research's heights -- trunnions at 7.97 / 10.56 / 8.66 m, 5-inch mounts at 8.1, Tomahawks at 10.7, Phalanx at
## 16 and 13 -- over step 3's shape, where turret 1 and the forward 5-inch mounts would have stood inside the forecastle,
## the other four mounts 0.8 m over the main deck, the midships Tomahawks 3.8 m over it and the forward Phalanx 10 m up in
## the air. A turret is the research's own rule instead: its trunnions 2.5 m over the deck it stands on, turret 2 on a
## barbette one level (2.6 m) higher. Turret 3, on the main deck the shape has where the research does, comes out at
## 8.4 m against Slover's 8.66. `tests/ship_models.gd` holds every fitting's foot on a part and its middle out of all.
##
## THE FORECASTLE'S SHEER is the shape's (carrier lane step 4b): the real deck falls from 9.1 m at the stem to about 5.1 m
## amidships, and the shape has it as stairs -- 9.1, 7.3, then 5.5 under turrets 1 and 2 -- where step 3 kept it flat at
## 9.1 m back to z -20, turret 2 stood 3.6 m too high on it and hid the forecastle from the pilot house.
##
## TURRETS 2 AND 3 TRAIN (plan item 22, 2026-09-16): they are the mounts the two turret seats work, so their gunhouses
## and barrels are NOT in this welded mesh -- `gunhouse` builds one as its own mesh about the trunnion, and `VehicleView`
## turns it where the simulation says the mount is pointing. What stays welded is what does not move: turret 2's barbette,
## and the whole of turret 1, which nobody works. No lights, no wake.
##
## FRAME: the ship's own, origin midships on the waterline, +X starboard, -Z to the bow, as the research measures it.

const HAZE := Color(0.45, 0.48, 0.51)
const TEAK := Color(0.36, 0.30, 0.23)
const STEEL := Color(0.32, 0.34, 0.36)
const BLACK := Color(0.06, 0.06, 0.07)
const WHITE := Color(0.88, 0.88, 0.85)

## THE MAIN BATTERY: where along the ship each triple turret's centre is (SINGLE, Slover's US Navy pages; the crew
## handbook's frame numbers agree) and how far it stands raised over the deck under it. Turret 2 superfires over turret 1
## from one superstructure level up (ESTIMATE, 2.6 m); turret 3 faces aft.
##
## `mount` IS THE SIMULATION'S MOUNT A TURRET IS, or -1 for one nobody works. Its trunnion is then the simulation's
## (`naval_gun_at`, which stands it on the same deck by the same TRUNNION and `raised`), and `tests/big_guns.gd` holds the
## two tables to each other.
const TURRETS: Array[Dictionary] = [
	{"z": -66.9, "raised": 0.0, "aft": false, "mount": -1},
	{"z": -45.0, "raised": 2.6, "aft": false, "mount": 0},
	{"z": 60.5, "raised": 0.0, "aft": true, "mount": 1},
]
## A turret's trunnions stand this far over the deck it sits on (ESTIMATE: the research's cross-check of Slover's heights
## against the freeboard). A 16-inch/50 barrel is 20.3 m, fifty calibres of 406 mm; a gunhouse about 13 m across and a
## barbette 12 m (both ESTIMATE, the barbette unverified).
const TRUNNION: float = 2.5
const BARREL: float = 20.3
## How thick a big gun's barrel is drawn, metres, square. tests/turret_seats.gd holds a gunner's sight line clear of its top.
const BORE: float = 0.7
const GUNHOUSE := Vector3(13.0, 4.2, 11.0)
## How thick a turret gunner's hood column is, metres: inside the tub's 1.8 m, and narrower than the gunhouse roof it
## rises through.
const HOOD_COLUMN: float = 0.8
const BARBETTE: float = 12.0

## THE SECONDARY BATTERY: the three twin 5-inch/38 mounts a side that the refit kept (ESTIMATE places; which went is SINGLE
## on "the aft ones").
const FIVE_INCH_Z: Array[float] = [-28.0, -16.0, -4.0]
const FIVE_INCH_X: float = 11.5
const FIVE_INCH := Vector3(4.6, 2.8, 5.8)

## THE REFIT'S MISSILES: two groups of Tomahawk armoured box launchers either side of the centreline (the order CONFIRMED,
## places ESTIMATE), and the Harpoon canisters abreast the after funnel -- 3 m forward of the research's +23, so they stand
## clear of the after superstructure's face.
const TOMAHAWK_Z: Array[float] = [7.0, 38.0]
const TOMAHAWK_X: float = 5.0
const TOMAHAWK := Vector3(2.2, 2.0, 7.5)
const HARPOON := Vector2(6.0, 20.0)
const HARPOON_RACK := Vector3(1.6, 1.4, 4.2)
## FOUR PHALANX MOUNTS, "two just behind the bridge and two forward and outboard of the after funnel" (SINGLE), on the
## superstructure the research's heights put them on: the 04 level behind the pilot house and the after superstructure's
## roof. The shape's superstructure is 14 m wide, so they stand inboard of the research's x of 9 and 10.
const PHALANX: Array[Vector2] = [Vector2(-6.0, -18.0), Vector2(6.0, -18.0), Vector2(-5.5, 28.0), Vector2(5.5, 28.0)]
const PHALANX_BASE := Vector3(1.8, 1.4, 1.8)

## THE HELICOPTER PAD on the fantail, offset to port (the fantail CONFIRMED, the offset ESTIMATE).
const PAD := Vector2(-3.0, 105.0)
const PAD_RADIUS: float = 9.0


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}` -- `Superstructure`'s from the parts with the battleship's fittings in
## the same mesh, every solid fitting added to the panels the helm's view is checked against, and the box each fitting
## stands on the ship by.
static func build(geometry: Dictionary, helm: String) -> Dictionary:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	# INTO ONE TOOL: the parts first, then the fittings. Copying a finished mesh in with `append_from` was the first draft,
	# and whether its vertex colours survive the copy is an engine detail this does not need to depend on.
	var panels: Array[AABB] = Superstructure.build_into(tool, geometry, helm)
	var fittings: Array[AABB] = []
	_teak_on_the_decks(tool, parts)
	for turret in TURRETS:
		_turret(tool, parts, turret, panels, fittings)
	_hoods(tool, parts, panels, fittings)
	for z in FIVE_INCH_Z:
		for side in [-1.0, 1.0]:
			_five_inch(tool, parts, Vector2(side * FIVE_INCH_X, z), side, panels, fittings)
	for z in TOMAHAWK_Z:
		for side in [-1.0, 1.0]:
			_stand(tool, parts, Vector2(side * TOMAHAWK_X, z), TOMAHAWK, HAZE, panels, fittings)
	for side in [-1.0, 1.0]:
		_stand(tool, parts, Vector2(side * HARPOON.x, HARPOON.y), HARPOON_RACK, HAZE, panels, fittings)
	for at in PHALANX:
		var base: AABB = _stand(tool, parts, at, PHALANX_BASE, HAZE, panels, fittings)
		var dome := AABB(Vector3(at.x - 0.65, base.end.y, at.y - 0.65), Vector3(1.3, 1.9, 1.3))
		Plating.box(tool, dome.get_center(), dome.size, WHITE)
		panels.append(dome)
		Plating.box(tool, Vector3(at.x, base.end.y + 0.7, at.y - 1.6), Vector3(0.25, 0.25, 2.0), BLACK)
	_helicopter_pad(tool, parts)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## A BOX STOOD ON THE SHIP at a plan point: its foot on the part under it, `size` across, drawn, and handed back as both a
## panel and a fitting.
static func _stand(tool: SurfaceTool, parts: Array, at: Vector2, size: Vector3, tint: Color, panels: Array[AABB],
		fittings: Array[AABB]) -> AABB:
	var box := AABB(Vector3(at.x - size.x * 0.5, _foot(parts, at), at.y - size.z * 0.5), size)
	Plating.box(tool, box.get_center(), box.size, tint)
	panels.append(box)
	fittings.append(box)
	return box


## THE TURRET GUNNERS' HOODS (plan item 22d, 2026-09-16): under each `station` part -- a gunner's tub, which the
## simulation stands three metres over its turret's gunhouse roof, on the training axis -- a column from the deck to the
## tub's floor, so the tub stands on the ship. It rises through the gunhouse, which turns round it as a hull-fixed
## director column would: the gunner does not turn with the turret, because a headset view yawed with no head motion is a
## comfort failure (tests/ranging_sight.gd).
static func _hoods(tool: SurfaceTool, parts: Array, panels: Array[AABB], fittings: Array[AABB]) -> void:
	for part in parts:
		if String(part.get("part", "")) != "station":
			continue
		var at: Vector2 = Wheelhouse.outline_rect(part.get("outline", PackedVector2Array())).get_center()
		var foot: float = _foot(parts, at)
		var floor_at: float = float(part.get("bottom", 0.0)) - 0.1
		if floor_at - foot < 0.5:
			continue
		var column := AABB(Vector3(at.x - HOOD_COLUMN * 0.5, foot, at.y - HOOD_COLUMN * 0.5),
			Vector3(HOOD_COLUMN, floor_at - foot, HOOD_COLUMN))
		Plating.box(tool, column.get_center(), column.size, HAZE)
		panels.append(column)
		fittings.append(column)


## The deck under a plan point. Over the sea there is none, and the fitting is left at the waterline, where
## `tests/ship_models.gd` finds it standing on nothing.
static func _foot(parts: Array, at: Vector2) -> float:
	var top: float = Superstructure.top_under(parts, at)
	return 0.0 if is_inf(top) else top


## TEAK: the Iowas kept wooden weather decks, which from the air is the colour that says "battleship" before its turrets
## do. Painted a hair above each deck part's top.
static func _teak_on_the_decks(tool: SurfaceTool, parts: Array) -> void:
	for part in parts:
		if String(part.get("part", "")) == "deck":
			Plating.paint(tool, part["outline"], float(part["top"]) + 0.02, TEAK)


## A TRIPLE TURRET: a barbette when it is raised, a gunhouse on it, a face plate where the barrels come through, and three
## barrels at the trunnions. A raised turret stands on the ship by its barbette, a turret on the deck by its gunhouse.
static func _turret(tool: SurfaceTool, parts: Array, turret: Dictionary, panels: Array[AABB],
		fittings: Array[AABB]) -> void:
	var z: float = float(turret["z"])
	var raised: float = float(turret["raised"])
	var facing: float = 1.0 if bool(turret["aft"]) else -1.0
	var seat: float = _foot(parts, Vector2(0.0, z)) + raised
	if raised > 0.0:
		_stand(tool, parts, Vector2(0.0, z), Vector3(BARBETTE, raised, BARBETTE), HAZE, panels, fittings)
	var house := AABB(Vector3(-GUNHOUSE.x * 0.5, seat, z - GUNHOUSE.z * 0.5), GUNHOUSE)
	panels.append(house)
	if raised <= 0.0:
		fittings.append(house)
	var trunnion: float = seat + TRUNNION
	var face: float = z + facing * GUNHOUSE.z * 0.5
	for x in [-3.0, 0.0, 3.0]:
		var muzzle: float = face + facing * BARREL
		panels.append(AABB(Vector3(x - BORE * 0.5, trunnion - BORE * 0.5, minf(face, muzzle)), Vector3(BORE, BORE, BARREL)))
	# A TURRET A SEAT WORKS IS DRAWN BY `gunhouse`, where it can be turned: its footprint and its panels stay above, so the
	# helm's view and the fittings' checks still see it at rest.
	if int(turret.get("mount", -1)) >= 0:
		return
	Plating.box(tool, house.get_center(), house.size, HAZE)
	Plating.box(tool, Vector3(0.0, trunnion, face), Vector3(GUNHOUSE.x * 0.9, GUNHOUSE.y * 0.6, 0.4), STEEL)
	for x in [-3.0, 0.0, 3.0]:
		var muzzle: float = face + facing * BARREL
		Plating.bar(tool, Vector2(x, face), Vector2(x, muzzle), BORE, trunnion - BORE * 0.5, trunnion + BORE * 0.5, STEEL)


## ONE TRAINING TURRET'S GUNHOUSE AND BARRELS, as a mesh about its TRUNNION, the barrels out along -Z: what `VehicleView`
## puts on a battleship's mount and turns by the mount's own two angles, so the barrels the shell leaves and the barrels
## everyone sees are one object. From the trunnion to the muzzle is half a gunhouse and a barrel -- the simulation's
## `kNavalBarrel` -- which `tests/big_guns.gd` holds.
static func gunhouse() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	Plating.box(tool, Vector3(0.0, -TRUNNION + GUNHOUSE.y * 0.5, 0.0), GUNHOUSE, HAZE)
	var face: float = -GUNHOUSE.z * 0.5
	Plating.box(tool, Vector3(0.0, 0.0, face), Vector3(GUNHOUSE.x * 0.9, GUNHOUSE.y * 0.6, 0.4), STEEL)
	for x in [-3.0, 0.0, 3.0]:
		Plating.bar(tool, Vector2(x, face), Vector2(x, face - BARREL), BORE, -BORE * 0.5, BORE * 0.5, STEEL)
	return Plating.weld(tool)


## A TWIN 5-INCH MOUNT: a squat gunhouse and two barrels LAID FORE AND AFT, as a mount at rest is. The first draft trained
## them outboard, to keep the main-deck mounts' barrels out of a 9.1 m forecastle's side; with the forecastle lowered to the
## research's sheer that side is gone, and outboard they reached x 19.4, past cockpit-fleet's hull bounds (17.99).
static func _five_inch(tool: SurfaceTool, parts: Array, at: Vector2, _side: float, panels: Array[AABB],
		fittings: Array[AABB]) -> void:
	var mount: AABB = _stand(tool, parts, at, FIVE_INCH, HAZE, panels, fittings)
	var bore: float = mount.position.y + FIVE_INCH.y * 0.55
	var face: float = at.y - FIVE_INCH.z * 0.5
	for dx in [-0.8, 0.8]:
		Plating.bar(tool, Vector2(at.x + dx, face), Vector2(at.x + dx, face - 5.6), 0.3, bore - 0.15, bore + 0.15, STEEL)


## THE HELICOPTER PAD: a white circle of dashes and a white cross on the deck at the fantail.
static func _helicopter_pad(tool: SurfaceTool, parts: Array) -> void:
	var y: float = _foot(parts, PAD) + 0.04
	for i in range(24):
		var a0: float = TAU * float(i) / 24.0
		var a1: float = a0 + TAU / 48.0
		Plating.line(tool, PAD + Vector2(cos(a0), sin(a0)) * PAD_RADIUS, PAD + Vector2(cos(a1), sin(a1)) * PAD_RADIUS, 0.4,
			y, WHITE)
	Plating.line(tool, PAD + Vector2(-4.0, 0.0), PAD + Vector2(4.0, 0.0), 0.6, y, WHITE)
	Plating.line(tool, PAD + Vector2(0.0, -4.0), PAD + Vector2(0.0, 4.0), 0.6, y, WHITE)
