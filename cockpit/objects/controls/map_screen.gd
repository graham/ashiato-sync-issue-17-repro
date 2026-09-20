@tool
extends VehicleControl
class_name MapScreen
## A dedicated moving-map glass. The terrain texture sleeps between LevelMap
## rebuilds; only the small marker overlay is refreshed at the cockpit's 5 Hz.

const PAGE: PackedScene = preload("res://ui/menus/map_canvas.tscn")
const SIZE := Vector2(0.20, 0.16)

var _screen: TouchPanel
var _last_revision: int = -1


func label_text() -> String:
	return "MAP\nCREW"


func _build() -> void:
	control_name = "map"
	channel = -1
	scope = Scope.PILOT
	# A control must have its own visible body before it enters the scene tree;
	# the builder measures every catalogue part immediately after setup.
	var case := BoxMesh.new()
	case.size = Vector3(SIZE.x + 0.02, SIZE.y + 0.02, 0.012)
	_make_mesh(case, Color(0.055, 0.065, 0.075), Vector3(0.0, 0.0, -0.008))
	_screen = TouchPanel.new()
	_screen.name = "Glass"
	_screen.page = PAGE
	_screen.size = SIZE
	_screen.pixels = 768
	_screen.bezel = true
	add_child(_screen)


func taken_by() -> int:
	return Bind.Take.NONE


func faces_the_eye() -> bool:
	return true


func show_map(map: LevelMap, markers: Array[Dictionary]) -> void:
	if _screen == null:
		return
	var page := _screen.shown() as MapCanvas
	if page == null:
		return
	page.show_map(map, markers)
	_screen.redraw()
	_last_revision = map.render_count if map != null else -1


func map_canvas() -> MapCanvas:
	return _screen.shown() as MapCanvas if _screen != null else null
