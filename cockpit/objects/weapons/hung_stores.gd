extends Node3D
class_name HungStores
## THE MISSILES HANGING ON A JET'S RAILS: one faceted missile a rail, where the simulation says the rail is, shown while
## the rail's bit on the craft's `stores` is set -- so a missile leaves its rail when it is launched and is back when
## the rail is rearmed, on every machine, from the one replicated byte.
##
## Asked for with the jets' weapons (lane/jetarms, 2026-09-18): the F/A-18F, the F-14D and the F-16 drew launcher rails
## and pylons with nothing on them. The rails are `Sim.missile_schema(kind)`'s -- the same points a missile is launched
## from and the MissileYard draws it leaving -- and never typed here, so the drawn missile and the one that flies start
## in the same place.
##
## HOUSE STYLE (modelling_here.md): low poly and faceted, a hexagonal body, a nose cone, four fins; one mesh a row,
## shared by every rail that carries it, and one material with the colour in the vertices.
##
## Sizes (Wikipedia infoboxes, read 2026-09-18): AIM-9X Sidewinder 3.02 m long, 127 mm across, 0.28 m over its tail
## fins; AIM-7 Sparrow 3.66 m, 203 mm, 0.81 m; AIM-120 AMRAAM 3.65 m, 178 mm, fins 0.45 m (ESTIMATE, not in the box).

## BY SIMULATION ROW NAME, the row a station carries (`missile_schema(kind).stations[].name`): length, body diameter, fin
## span, and where the mid-body wings are as a share of the length from the nose (0 for none).
const SHAPES: Dictionary = {
	"heat": {"length": 3.02, "diameter": 0.127, "fins": 0.28, "wings": 0.0, "canards": 0.16},
	"radar": {"length": 3.66, "diameter": 0.203, "fins": 0.62, "wings": 0.42, "canards": 0.0},
	"active radar": {"length": 3.65, "diameter": 0.178, "fins": 0.45, "wings": 0.40, "canards": 0.0},
}
const SIDES: int = 6
const BODY := Color(0.88, 0.89, 0.88)
const NOSE := Color(0.32, 0.33, 0.34)
const FIN := Color(0.80, 0.81, 0.80)
const BAND := Color(0.78, 0.66, 0.20)
const PYLON := Color(0.60, 0.62, 0.64)

## Each rail's missile, by pylon id; null where a pylon carries nothing drawn.
var _rails: Array[MeshInstance3D] = []


## ONE MISSILE A RAIL, from the kind's schema. Gun stations and rows with no shape here hang nothing.
##
## `pylons` is the rails whose airframe draws nothing to hang from, by pylon id, and how tall a pylon to draw above
## each missile to meet it, in metres (the catalogue's `store_pylons`). A pylon stays when its missile goes. Without
## them the F-14's four and the F-16's two AMRAAMs hung 0.06 to 0.18 m under nothing: tests/joined_parts.gd.
func fit(schema: Dictionary, pylons: Dictionary = {}) -> void:
	var material: StandardMaterial3D = ShipHull.painted()
	material.roughness = 0.5
	var meshes: Dictionary = {}
	for entry in (schema.get("stations", []) as Array):
		var station: Dictionary = entry
		var row: String = String(station.get("name", ""))
		if bool(station.get("gun", false)) or not SHAPES.has(row):
			continue
		if not meshes.has(row):
			meshes[row] = missile_mesh(SHAPES[row] as Dictionary)
		var ids: Array = station.get("pylon_ids", []) as Array
		var places: Array = station.get("pylons", []) as Array
		for i in range(mini(ids.size(), places.size())):
			var id: int = int(ids[i])
			if pylons.has(id):
				_hang_a_pylon(places[i] as Vector3, SHAPES[row] as Dictionary, float(pylons[id]), id)
			var rail := MeshInstance3D.new()
			rail.name = "Store%d" % id
			rail.mesh = meshes[row]
			rail.material_override = material
			rail.position = places[i] as Vector3
			add_child(rail)
			while _rails.size() <= id:
				_rails.append(null)
			_rails[id] = rail


## A PYLON above a missile's back: `tall` metres from the missile's top up into the airframe, half its length long.
func _hang_a_pylon(at: Vector3, shape: Dictionary, tall: float, id: int) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: float = float(shape["diameter"]) * 0.5
	Plating.box(tool, Vector3(0.0, top + tall * 0.5, 0.0), Vector3(0.09, tall, float(shape["length"]) * 0.5), PYLON)
	var pylon := MeshInstance3D.new()
	pylon.name = "Pylon%d" % id
	pylon.mesh = tool.commit()
	pylon.material_override = ShipHull.painted()
	pylon.position = at
	add_child(pylon)


## THE RAILS THAT STILL CARRY ONE, as the craft's `stores` bits say.
func show_loaded(stores: int) -> void:
	for id in range(_rails.size()):
		if _rails[id] != null:
			_rails[id].visible = (stores & (1 << id)) != 0


## WHICH RAILS ARE DRAWN CARRYING ONE, as bits: what the suite holds against `stores`.
func drawn() -> int:
	var bits: int = 0
	for id in range(_rails.size()):
		if _rails[id] != null and _rails[id].visible:
			bits |= 1 << id
	return bits


## Every rail with a missile hung on it, by pylon id.
func rails() -> Array[MeshInstance3D]:
	return _rails


## ONE MISSILE, nose to -Z and centred on its middle: a hexagonal body, a faceted nose cone, a dark tail, cruciform tail
## fins, and canards or mid-body wings where the row has them.
static func missile_mesh(shape: Dictionary) -> ArrayMesh:
	var length: float = float(shape["length"])
	var radius: float = float(shape["diameter"]) * 0.5
	var half: float = length * 0.5
	var nose_end: float = -half + radius * 5.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front: Array[Vector3] = _ring(radius, nose_end)
	var band: Array[Vector3] = _ring(radius, nose_end + radius * 2.0)
	var back: Array[Vector3] = _ring(radius, half)
	var tip := Vector3(0.0, 0.0, -half)
	for k in range(SIDES):
		var n: int = (k + 1) % SIDES
		var out: Vector3 = ((front[k] + front[n]) * 0.5 * Vector3(1.0, 1.0, 0.0)).normalized()
		# The nose cone, a facet to the tip.
		Plating.facing(tool, [tip, front[n], front[k], front[k]], out + Vector3(0.0, 0.0, -0.6), NOSE)
		# The band behind the seeker, then the body.
		Plating.facing(tool, [front[k], front[n], band[n], band[k]], out, BAND)
		Plating.facing(tool, [band[k], band[n], back[n], back[k]], out, BODY)
		# The tail's end, a dark cap.
		Plating.facing(tool, [Vector3(0.0, 0.0, half), back[k], back[n], back[n]], Vector3(0.0, 0.0, 1.0), NOSE)
	# FOUR FINS IN AN X, at the tail; and the same again, smaller, as canards or as wings where the row has them.
	var span: float = float(shape["fins"]) * 0.5
	_fins(tool, radius, span, half - 0.30, 0.28)
	if float(shape["canards"]) > 0.0:
		_fins(tool, radius, span * 0.9, -half + length * float(shape["canards"]), 0.16)
	if float(shape["wings"]) > 0.0:
		_fins(tool, radius, span * 0.85, -half + length * float(shape["wings"]), 0.45)
	return tool.commit()


## A RING of the body at `z`, flats top and bottom.
static func _ring(radius: float, z: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in range(SIDES):
		var angle: float = TAU * (float(k) + 0.5) / float(SIDES)
		out.append(Vector3(cos(angle) * radius, sin(angle) * radius, z))
	return out


## FOUR THIN FINS round the body at `z`, `chord` long, reaching `span` from the axis, in an X.
static func _fins(tool: SurfaceTool, radius: float, span: float, z: float, chord: float) -> void:
	if span <= radius:
		return
	var reach: float = span - radius * 0.5
	for k in range(4):
		var turn := Basis(Vector3(0.0, 0.0, 1.0), PI * 0.25 + PI * 0.5 * float(k))
		Plating.box(tool, turn * Vector3(radius * 0.5 + reach * 0.5, 0.0, z), Vector3(reach, 0.012, chord), FIN, turn)
