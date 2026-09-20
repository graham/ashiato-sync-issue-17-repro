extends Node
class_name LevelMap
## A DEAD, TOP-DOWN PICTURE OF ONE LEVEL. The 3D world is rendered only when
## `rebuild` is called; moving player arrows are ordinary Control overlays.
##
## Godot's documented `UPDATE_ONCE` mode switches itself back to disabled after
## one render. Keeping that policy here prevents a 1024 px second world view from
## becoming a per-frame cost.

signal rebuilt(revision: int)

const PIXELS := Vector2i(1024, 1024)
const ISLAND_HALF: float = Terrain.GROUND_HALF.x

var half_extent: float = ISLAND_HALF
var centre := Vector2.ZERO
var render_count: int = 0
var _viewport: SubViewport
var _camera: Camera3D
var _picture: ImageTexture


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "MapRender"
	_viewport.size = PIXELS
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_viewport.transparent_bg = false
	# Share the level's World3D, then freeze its picture. A SubViewport otherwise
	# owns an empty scenario and its camera sees only the background.
	_viewport.world_3d = get_viewport().world_3d
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.name = "MapCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("17283a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.82
	environment.fog_enabled = false
	_camera.environment = environment
	_viewport.add_child(_camera)
	_configure_camera()


func configure(chart: LevelChart) -> void:
	if chart != null and chart.world == "alpine":
		half_extent = float(chart.ground.get("world_half", GroundTuning.values().get("world_half", 32768)))
	elif chart != null and chart.indoors():
		half_extent = maxf(chart.apart * 5.0, 20.0)
	else:
		half_extent = ISLAND_HALF
	centre = Vector2(chart.spawn_at.x, chart.spawn_at.z) if chart != null and chart.indoors() else Vector2.ZERO
	_configure_camera()


func _configure_camera() -> void:
	if _camera == null:
		return
	_camera.size = half_extent * 2.0
	_camera.near = 1.0
	_camera.far = maxf(half_extent * 2.0, 10000.0)
	_camera.position = Vector3(centre.x, maxf(half_extent, 8000.0), centre.y)
	_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)


func rebuild() -> void:
	if _viewport == null:
		return
	render_count += 1
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_capture_after_render(render_count)


func _capture_after_render(revision: int) -> void:
	# A SubViewportTexture cannot be sampled reliably by another SubViewport
	# (TouchPanel is one). Freeze the rendered frame into an ordinary texture so
	# clipboard and cockpit surfaces consume the exact same portable picture.
	await RenderingServer.frame_post_draw
	if _viewport == null:
		return
	var image := _viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		_picture = ImageTexture.create_from_image(image)
	rebuilt.emit(revision)


func texture() -> Texture2D:
	if _picture != null:
		return _picture
	return _viewport.get_texture() if _viewport != null else null


func update_mode() -> int:
	return _viewport.render_target_update_mode if _viewport != null else SubViewport.UPDATE_DISABLED


## Project through the same camera which authored the frozen texture. Keeping
## this conversion here gives every map surface one projection contract.
func to_map(world: Vector3) -> Vector2:
	if _camera != null:
		return _camera.unproject_position(world)
	# Pre-tree fallback for callers constructing the service in a unit fixture.
	var span := half_extent * 2.0
	return Vector2(
		(world.x - centre.x + half_extent) / span * PIXELS.x,
		(world.z - centre.y + half_extent) / span * PIXELS.y)


func from_map(pixel: Vector2) -> Vector3:
	var span := half_extent * 2.0
	return Vector3(
		centre.x - half_extent + pixel.x / PIXELS.x * span,
		0.0,
		centre.y - half_extent + pixel.y / PIXELS.y * span)


## Map surfaces consume Item 15's authoritative replicated profile through Net;
## they never keep a second roster or synthesize a competing colour assignment.
static func marker_style(client_id: int) -> Dictionary:
	return {"name": Net.name_of(client_id), "colour": Net.colour_of(client_id)}


static func markers(manifest: Array, states: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for craft_any in manifest:
		var craft := craft_any as Dictionary
		var state := states.get(int(craft.get("vehicle", 0)), {}) as Dictionary
		if not state.get("position") is Vector3:
			continue
		var client_id := int(craft.get("names", -1))
		var style := marker_style(client_id)
		var nose := Vector3.FORWARD
		if state.get("basis") is Quaternion:
			nose = (state["basis"] as Quaternion) * Vector3.FORWARD
		out.append({"client": client_id, "vehicle": int(craft.get("vehicle", 0)),
			"kind": int(craft.get("kind", -1)),
			"position": state["position"], "heading": atan2(nose.x, -nose.z),
			"yours": bool(craft.get("yours", false)), "name": style["name"],
			"colour": style["colour"], "distance": float(craft.get("distance", -1.0)),
			# A CREWED CRAFT IS A PERSON, and its marker is keyed by the client id, which means the same
			# on every machine. `AirPicture` adds the craft nobody is in beside these, keyed negative;
			# both are built here and in `AirPicture` and nowhere else.
			"manned": true, "contact": client_id})
	return out
