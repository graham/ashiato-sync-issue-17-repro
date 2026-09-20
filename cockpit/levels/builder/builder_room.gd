extends Node3D
class_name BuilderRoom

signal chose_craft(kind: int)
signal chose_version(version: String)
signal chose_save()
signal chose_board(seat: int)

const PAGE := preload("res://ui/menus/builder_menu.tscn")
const WALL: float = 0.3
var board: TouchPanel = null
var inspector: ModelInspector = null


static func claims(chart: LevelChart) -> bool:
	return chart != null and chart.id == "builder"


static func inside() -> Vector3:
	var half := Vector3(20.0, 4.0, 14.0)
	for kind in VehicleCatalogue.pilotable_kinds():
		if kind == Sim.Kind.SEGWAY: continue
		var visual := conservative_visual_half(kind)
		half.x = maxf(half.x, visual.x + 8.0)
		half.y = maxf(half.y, visual.y + 4.0)
		half.z = maxf(half.z, visual.z + 8.0)
	return half


## A conservative envelope for generated VehicleView fittings. Wings use `span` rather
## than collision extents; ship towers and rotor masts intentionally rise above the native
## box. The visual harness checks each real AABB against this room too.
static func conservative_visual_half(kind: int) -> Vector3:
	var geometry := Sim.geometry_of(kind)
	var extents := geometry.get("extents", Vector3.ONE) as Vector3
	return Vector3(maxf(extents.x, float(geometry.get("span", 0.0))), extents.y + 20.0, extents.z)


static func boxes(_chart: LevelChart) -> Array[Dictionary]:
	var half := inside()
	return [
		{"position": Vector3(0, half.y, -half.z - WALL), "half_extents": Vector3(half.x + WALL, half.y, WALL)},
		{"position": Vector3(0, half.y, half.z + WALL), "half_extents": Vector3(half.x + WALL, half.y, WALL)},
		{"position": Vector3(-half.x - WALL, half.y, 0), "half_extents": Vector3(WALL, half.y, half.z)},
		{"position": Vector3(half.x + WALL, half.y, 0), "half_extents": Vector3(WALL, half.y, half.z)},
		{"position": Vector3(0, half.y * 2.0 + WALL, 0), "half_extents": Vector3(half.x + WALL, WALL, half.z + WALL)},
	]


func stand_in(chart: LevelChart) -> void:
	var half := inside()
	var floor := MeshInstance3D.new(); var floor_mesh := BoxMesh.new(); floor_mesh.size = Vector3(half.x * 2.0, WALL, half.z * 2.0)
	floor.mesh = floor_mesh; floor.position = Vector3(0, -WALL * 0.5, 0); floor.material_override = _paint(Color(0.14, 0.15, 0.17)); add_child(floor)
	var solids := boxes(chart); var names := ["NorthWall", "SouthWall", "WestWall", "EastWall", "Ceiling"]
	for i in range(solids.size()):
		var wall := MeshInstance3D.new(); wall.name = names[i]; var mesh := BoxMesh.new(); mesh.size = (solids[i]["half_extents"] as Vector3) * 2.0
		wall.mesh = mesh; wall.position = solids[i]["position"]; wall.material_override = _paint(Color(0.25, 0.27, 0.30)); add_child(wall)
	var title := Label3D.new(); title.text = "COCKPIT WORKSHOP"; title.font_size = 96; title.pixel_size = 0.003
	title.position = Vector3(0, 3.0, -half.z + 0.05); add_child(title)
	board = TouchPanel.new(); board.name = "BuilderBoard"; board.page = PAGE; board.size = Vector2(2.8, 2.08); board.pixels = 1024
	board.position = Vector3(minf(half.x - 2.0, 5.0), 1.55, -half.z + 0.06); add_child(board)
	inspector = ModelInspector.new(); inspector.name = "ModelInspector"; add_child(inspector)
	for x in [-0.5, 0.5]:
		var light := OmniLight3D.new(); light.position = Vector3(half.x * x, half.y * 1.5, 0); light.omni_range = maxf(half.x, half.z); light.light_energy = 4.0; add_child(light)
	await get_tree().process_frame
	var page := board.shown() as BuilderMenu
	if page != null:
		page.chose_craft.connect(func(kind: int): chose_craft.emit(kind))
		page.chose_version.connect(func(version: String): chose_version.emit(version))
		page.chose_save.connect(func(): chose_save.emit())
		page.chose_board.connect(func(seat: int): chose_board.emit(seat))
		page.toggled_model_layer.connect(_toggle_model_layer)


func show_selection(kind: int, version: String, words: String = "") -> void:
	var page := board.shown() as BuilderMenu if board != null else null
	if page != null: page.show_selection(kind, version, words); board.redraw()


func inspect(view: VehicleView) -> void:
	if inspector != null: inspector.inspect(view)


func _toggle_model_layer(layer: StringName, shown: bool) -> void:
	if inspector == null: return
	match layer:
		&"exterior": inspector.show_exterior(shown)
		&"interior": inspector.show_interior(shown)
		&"overlays": inspector.show_overlays(shown)


static func _paint(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.albedo_color = colour; material.roughness = 0.85; return material
