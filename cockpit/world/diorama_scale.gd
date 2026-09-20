extends RefCounted
class_name DioramaScale
## THE ONE PLACE THE WORLD IS SHRUNK, and the only place (CLAUDE.md rule 4). Every vertex of the diorama's board, every
## piece standing on it and every click read back off it goes through `to_board` or `from_board` and through nothing
## else. A scale typed in a second place is the bug this whole feature would otherwise ship, because the two copies
## would agree for a week: the board would be built at one factor and the aeroplanes placed at another, and the first
## symptom is aircraft flying through a mountain that is drawn in the right place.
##
## WHY THERE IS A DIORAMA AT ALL. The user, 2026-09-20: *"we shouldn't use a camera and have godot just view the map,
## we should regenerate a view given the data we have (that way it doesn't incur the same 3d drawing issues and
## distance calculations, make a new "diorama" of sorts that shows the state of all the units, almost like a live
## chessboard with the terrain and planes, boats, flying around."*
##
## `world/level_map.gd` points an orthographic camera at the REAL world at REAL scale, eight kilometres out and eight
## kilometres up, renders once and freezes the picture. A diorama is still looked at by a camera -- there is no drawing
## 3D without one -- but the camera looks at a board about a metre across sitting AT THE ORIGIN, built out of numbers.
## That is where the win the user names comes from: no distance from the origin, no level of detail, no terrain
## geometry, no shaders that care where the camera is.
##
## ---------------------------------------------------------------------------------------------------
## ONE FACTOR, FOR X, Y AND Z ALIKE, AND NO VERTICAL EXAGGERATION
## ---------------------------------------------------------------------------------------------------
##
## The obvious thing to reach for is a taller-than-wide board, because a model railway does it and because relief looks
## better stretched. **It is refused here and the reason is that altitude is the one thing this board can say that the
## flat plot cannot** (`ui/menus/map_canvas.gd` draws a triangle per contact and has nowhere to put a height).
##
## Exaggerate the terrain and you must exaggerate the aircraft by the identical factor or a contact at 300 m appears to
## fly INSIDE a ridge that is really 600 m and is drawn at 2,400. Exaggerate both and a contact at ten kilometres stands
## metres clear of a board a metre wide, off the top of any view that also shows the ground. Neither is a board somebody
## can read, and both are the board lying about a number a controller is about to say on the radio.
##
## SO IT IS TRUE SCALE, and MEASURED (`tests/diorama.gd`, 2026-09-20) it is perfectly legible. Over the island's
## +/-7,200 m at `BOARD_HALF` the factor is exactly **1:12,000**, and the island's relief -- 653 m from the water to the
## highest rock the board's 150 m grid catches -- stands **54 mm** proud of a 1.2 m board. That is a mountain you can
## see across a table. A contact at 300 m is 25 mm up its stalk, clearly above the rock; one at 10 km is 0.83 m up,
## which is high, and it is high because it IS. A 2,400 m separation between two contacts over one spot draws as 200 mm
## of daylight between them, where the flat plot draws one marker on top of the other.
##
## IF A PICTURE EVER SHOWS THAT UNREADABLE, the answer is a named constant here with the measurement beside it and the
## board saying out loud that it is stretched -- not a quiet factor of four.

## HOW BIG THE BOARD IS, in board metres from the middle to an edge. 0.6 makes a 1.2 m square: a table somebody stands
## at, which is the object the user described. Nothing else in this file is a choice; this is the choice.
const BOARD_HALF: float = 0.6

## HOW MUCH WORLD THE BOARD COVERS, in metres from the middle to an edge, and where that middle is. Both handed in from
## `LevelMap` (`half_extent`, `centre`) rather than worked out again, so the board and the flat plot cover the same
## ground by construction and a level that changes either moves both.
var half_extent: float = Terrain.GROUND_HALF.x
var centre := Vector2.ZERO


func _init(covering: float = Terrain.GROUND_HALF.x, middle: Vector2 = Vector2.ZERO) -> void:
	half_extent = maxf(covering, 1.0)
	centre = middle


## THE FACTOR: board metres to a world metre. Everything below is this and an offset.
func factor() -> float:
	return BOARD_HALF / half_extent


## HOW MANY WORLD METRES TO A BOARD METRE, which is the number a person says out loud ("one to twelve thousand").
## Printed by the probe and by the suite's detail lines; never used to do arithmetic, because that is `factor`'s job.
func world_metres_per_board_metre() -> float:
	return half_extent / BOARD_HALF


## A PLACE IN THE WORLD, AS A PLACE ON THE BOARD. The board's origin is the map's middle at SEA LEVEL, so a contact
## floating at y = 0 sits exactly on the water and the sign of its board y is the sign of its altitude.
func to_board(world: Vector3) -> Vector3:
	var k: float = factor()
	return Vector3((world.x - centre.x) * k, (world.y - Terrain.SEA_LEVEL) * k, (world.z - centre.y) * k)


## AND BACK AGAIN, exactly. `tests/diorama.gd` holds the round trip in both directions at sampled points, because a
## projection that is not invertible is one that has quietly acquired a second factor.
func from_board(board: Vector3) -> Vector3:
	var k: float = factor()
	return Vector3(board.x / k + centre.x, board.y / k + Terrain.SEA_LEVEL, board.z / k + centre.y)


## A LENGTH, not a place: no centre offset and no sea level. For a height above the ground or a span across it.
func length_to_board(metres: float) -> float:
	return metres * factor()
