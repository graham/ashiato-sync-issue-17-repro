extends RefCounted
## A ROCK BOX IN EVERY KILOMETRE OF A MAP, for the suites that drive the scenery yard's streaming over a big tiled world
## (`scenery_rings`, `scenery_workers`). The island's mountains were their subject; since the mountains became ranges drawn
## by MountainView (2026-09-18) the island has no rock box left to stream, and the yard's rings are the yard's whatever
## the island draws. So the subject is laid here: one box in every STRIDE-th WorldMap cell each way of a square `across`
## metres wide about the origin, placed in its cell and sized by the hash, the same on every run.
##
## EVERY SECOND CELL: 1,296 rock cells over the 72 km map, near the ~1,500 the tiled island's mountains filled. A box in
## every cell was 5,184, and `scenery_workers` and `scenery_memory` ran past their 180 s deadlines on it.
const STRIDE: int = 2


static func laid(across: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cells: int = int(across / WorldMap.CELL)
	for i in range(0, cells, STRIDE):
		for j in range(0, cells, STRIDE):
			var seed_value: int = i * 131 + j
			var corner := Vector3((float(i) - float(cells) * 0.5) * WorldMap.CELL, 0.0,
				(float(j) - float(cells) * 0.5) * WorldMap.CELL)
			var half := Vector3(40.0 + 160.0 * Terrain.hash01(seed_value, 1), 30.0 + 200.0 * Terrain.hash01(seed_value, 2),
				40.0 + 160.0 * Terrain.hash01(seed_value, 3))
			var at: Vector3 = corner + Vector3(half.x + (WorldMap.CELL - 2.0 * half.x) * Terrain.hash01(seed_value, 4), half.y,
				half.z + (WorldMap.CELL - 2.0 * half.z) * Terrain.hash01(seed_value, 5))
			out.append({"position": at, "half_extents": half, "group": Terrain.Group.ROCK})
	return out
