extends Node3D
class_name DeviceYard
## THE DEVICE YARD: a level-sized visual and collision fixture for the `RoomControlBank` native component.
##
## The bank is server-owned. This node is only a view and a request bridge: it never applies a pressed value locally.
## A new native extension is detected at runtime so an older installed DLL still opens the yard as an explicitly OFFLINE
## fixture. The contract is deliberately narrow: `room_control_configure(room, revision, count)`,
## `room_control_state(room, revision)` and `room_control_submit(room, revision, index, value)`. The native layer owns
## admission, proximity, rate limits, replication and page sequencing.
##
## The count lives in `LevelChart.yard_devices`, and hence in the level content hash. 100, 250 and 500 are practical
## presets; any whole count 1..500 is valid for experiments. A host changes it by serving a different level chart, never
## with a local command-line flag, because a room registry is part of a network session's definition.
##
## MultiMesh is intentional: hundreds of `MeshInstance3D`s would turn an endpoint-count test into a node-count test.
## Godot's stable MultiMesh docs describe one GPU-instanced mesh shared by many instances:
## https://docs.godotengine.org/en/stable/classes/class_multimesh.html

const LEVEL_ID := "device_yard"
const ROOM_CONTROL_REVISION := 1
const ROOMS: PackedStringArray = [&"alpha", &"bravo"]
const PRESETS: PackedInt32Array = [100, 250, 500]
const ROOM_HALF := Vector3(15.0, 3.2, 12.0)
const ROOM_CENTRES: Dictionary = {&"alpha": Vector3(-16.0, 0.0, 0.0), &"bravo": Vector3(16.0, 0.0, 0.0)}
const WALL: float = 0.25
const FLOOR: float = 0.0
const PODIUM := Vector3(0.62, 0.85, 0.46)
const PANEL := Vector3(0.46, 0.34, 0.035)
## A player is seated in a Segway, not given a free flying editor camera.  This keeps a
## selected endpoint close enough to use from that vehicle while still requiring the
## player to move through the room for another bank.
const POINTER_REACH := 2.4
const POINTER_RADIUS := 0.30

var endpoint_count: int = LevelChart.YARD_DEVICES_DEFAULT
var _room_control: Object = null
var _room_control_admitted := false
var _banks: Dictionary = {}
var _pointer_marker: MeshInstance3D = null

## A local observation that intent entered the native client queue.  It is deliberately
## not an "applied" signal: only the replicated state vector proves that.
signal endpoint_request_queued(room_id: StringName, index: int, value: int)


static func claims(chart: LevelChart) -> bool:
	return chart != null and chart.id == LEVEL_ID


static func is_valid_density(count: int) -> bool:
	return count >= LevelChart.YARD_DEVICES_LEAST and count <= LevelChart.YARD_DEVICES_MOST


static func room_centre(room_id: StringName) -> Vector3:
	return ROOM_CENTRES.get(room_id, Vector3.ZERO)


## One list feeds simulation collision and the rendered shell. There are two fully separate rooms: no shared visual
## bank, no doorway that suggests a bank crosses the boundary, and later no server scope that can accidentally span both.
static func boxes(_chart: LevelChart) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for room_id in ROOMS:
		var centre: Vector3 = room_centre(room_id)
		var half_high: float = ROOM_HALF.y * 0.5
		out.append({"position": centre + Vector3(0.0, half_high, -ROOM_HALF.z - WALL),
			"half_extents": Vector3(ROOM_HALF.x + WALL, half_high, WALL), "room": room_id})
		out.append({"position": centre + Vector3(0.0, half_high, ROOM_HALF.z + WALL),
			"half_extents": Vector3(ROOM_HALF.x + WALL, half_high, WALL), "room": room_id})
		out.append({"position": centre + Vector3(-ROOM_HALF.x - WALL, half_high, 0.0),
			"half_extents": Vector3(WALL, half_high, ROOM_HALF.z), "room": room_id})
		out.append({"position": centre + Vector3(ROOM_HALF.x + WALL, half_high, 0.0),
			"half_extents": Vector3(WALL, half_high, ROOM_HALF.z), "room": room_id})
		out.append({"position": centre + Vector3(0.0, ROOM_HALF.y + WALL, 0.0),
			"half_extents": Vector3(ROOM_HALF.x + WALL, WALL, ROOM_HALF.z + WALL), "room": room_id})
	return out


## Positions are an address contract, not a simulation state. Endpoint 0 stays at the first place in any density so a
## future RoomControlBank can retain a stable index while the author raises its capacity.
static func endpoint_places(room_id: StringName, count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not is_valid_density(count) or not ROOMS.has(room_id):
		return out
	var columns: int = ceili(sqrt(float(count)))
	var rows: int = ceili(float(count) / float(columns))
	var spacing_x: float = minf(1.05, (ROOM_HALF.x * 2.0 - 2.6) / maxf(1.0, float(columns - 1)))
	var spacing_z: float = minf(1.00, (ROOM_HALF.z * 2.0 - 3.2) / maxf(1.0, float(rows - 1)))
	var origin: Vector3 = room_centre(room_id) + Vector3(-float(columns - 1) * spacing_x * 0.5, PODIUM.y * 0.5,
		-float(rows - 1) * spacing_z * 0.5)
	for index in range(count):
		out.append(origin + Vector3(float(index % columns) * spacing_x, 0.0, float(index / columns) * spacing_z))
	return out


func stand_in(chart: LevelChart) -> void:
	endpoint_count = chart.yard_devices
	for room_id in ROOMS:
		_draw_room(room_id)
		_draw_endpoints(room_id, endpoint_count)
		_draw_sign(room_id)
	bind_room_control(_room_control)


func report() -> Dictionary:
	return {"rooms": ROOMS, "endpoints_per_room": endpoint_count, "endpoints_total": endpoint_count * ROOMS.size(),
		"preset": PRESETS.has(endpoint_count), "room_control_online": room_control_online(),
		"registry_revision": ROOM_CONTROL_REVISION}


## Stable author-facing identities. The index is the compact wire address; the id is for logs, tools and assertions.
## It is never a player-provided address, and changing density does not renumber existing endpoint ids.
func endpoint_registry(room_id: StringName) -> Array[Dictionary]:
	var bank: Dictionary = _banks.get(room_id, {})
	return bank.get("registry", []) as Array[Dictionary]


func room_state(room_id: StringName) -> PackedByteArray:
	var bank: Dictionary = _banks.get(room_id, {})
	return bank.get("values", PackedByteArray()) as PackedByteArray


func display_colour(room_id: StringName, index: int) -> Color:
	var values := room_state(room_id)
	if not ROOMS.has(room_id) or index < 0 or index >= values.size():
		return Color.TRANSPARENT
	return _panel_colour(room_id, values[index])


func room_control_online() -> bool:
	return _room_control_admitted and _room_control_available()


func _room_control_available() -> bool:
	return _room_control != null and is_instance_valid(_room_control) \
		and _room_control.has_method("room_control_configure") \
		and _room_control.has_method("room_control_state") \
		and _room_control.has_method("room_control_submit")


## Safe to call before or after `stand_in`. An old extension remains a visibly OFFLINE level rather than a parse error.
func bind_room_control(api: Object) -> Dictionary:
	_room_control = api
	_room_control_admitted = false
	if not _room_control_available():
		_refresh_signs()
		return {"online": false, "error": "RoomControlBank API unavailable"}
	var admitted := true
	for room_id in ROOMS:
		var answer: Variant = _room_control.call("room_control_configure", room_id, ROOM_CONTROL_REVISION, endpoint_count)
		if answer is bool and not bool(answer):
			admitted = false
	_room_control_admitted = admitted
	if _room_control_admitted:
		poll_room_control()
	_refresh_signs()
	return {"online": admitted, "rooms": ROOMS, "revision": ROOM_CONTROL_REVISION, "count": endpoint_count}


## Called from the real level's process loop. State is an authoritative byte vector (0..255); malformed or stale-sized
## answers are ignored whole, so a partial page can never make a client mix two registry definitions.
func poll_room_control() -> bool:
	if not room_control_online():
		return false
	var changed := false
	for room_id in ROOMS:
		var answer: Variant = _room_control.call("room_control_state", room_id, ROOM_CONTROL_REVISION)
		var values := _state_bytes(answer)
		if values.size() != endpoint_count:
			continue
		changed = apply_room_state(room_id, values) or changed
	return changed


## Sends only an intent. The return says the bridge passed the request to native code, never that the value took effect.
func submit_endpoint(room_id: StringName, index: int, value: int) -> Dictionary:
	if not ROOMS.has(room_id) or index < 0 or index >= endpoint_count:
		return {"accepted": false, "error": "unknown endpoint"}
	if not room_control_online():
		return {"accepted": false, "error": "RoomControlBank API unavailable"}
	var answer: Variant = _room_control.call("room_control_submit", room_id, ROOM_CONTROL_REVISION, index,
		clampi(value, 0, 255))
	return {"accepted": bool(answer), "pending_authority": bool(answer)}


## The world-pointer contract used by `PilotRig`.  Endpoint bodies are one MultiMesh
## rather than hundreds of collision nodes, so a physics ray would have nothing useful
## to identify.  This deterministic ray/sphere address lookup names the same stable
## room/index registry entry that reaches the native bank; it never changes its state.
func world_pointer_hit(from: Vector3, along: Vector3, reach: float = POINTER_REACH) -> Dictionary:
	if along.length_squared() < 0.000001:
		return {}
	var direction := along.normalized()
	var best: Dictionary = {}
	var nearest := maxf(0.0, reach)
	for room_id in ROOMS:
		for entry in endpoint_registry(room_id):
			var centre: Vector3 = (entry as Dictionary).get("position", Vector3.ZERO) as Vector3
			# The player sees and points at the lit face, not the plinth's centre.
			centre += Vector3(0.0, PODIUM.y * 0.22, -PODIUM.z * 0.51)
			var distance := direction.dot(centre - from)
			if distance < 0.0 or distance > nearest:
				continue
			if centre.distance_squared_to(from + direction * distance) > POINTER_RADIUS * POINTER_RADIUS:
				continue
			nearest = distance
			best = {"room_id": room_id, "index": int((entry as Dictionary).get("index", -1)),
				"distance": distance, "device_id": String((entry as Dictionary).get("device_id", ""))}
	return best


## A press turns a binary yard endpoint on or off.  The value is only an intent: the
## current authoritative byte chooses the next request, and `submit_endpoint` leaves
## the displayed state untouched until the native page returns it.
func world_pointer_press(hit: Dictionary) -> Dictionary:
	var room_id := StringName(hit.get("room_id", ""))
	var index := int(hit.get("index", -1))
	if not ROOMS.has(room_id) or index < 0 or index >= endpoint_count:
		return {"accepted": false, "error": "unknown endpoint"}
	var values := room_state(room_id)
	var requested := 255 if index >= values.size() or values[index] == 0 else 0
	var answer := submit_endpoint(room_id, index, requested)
	if bool(answer.get("accepted", false)):
		endpoint_request_queued.emit(room_id, index, requested)
	answer["room_id"] = room_id
	answer["index"] = index
	answer["requested_value"] = requested
	return answer


## A local cursor is not simulated state.  It gives both desktop and VR players a
## visible answer to their ray without making an unacknowledged press look applied.
func world_pointer_hover(hit: Dictionary) -> void:
	if _pointer_marker == null:
		_pointer_marker = _make_pointer_marker()
		add_child(_pointer_marker)
	if hit.is_empty():
		_pointer_marker.visible = false
		return
	var room_id := StringName(hit.get("room_id", ""))
	var index := int(hit.get("index", -1))
	var registry := endpoint_registry(room_id)
	if index < 0 or index >= registry.size():
		_pointer_marker.visible = false
		return
	var entry := registry[index] as Dictionary
	_pointer_marker.global_position = (entry.get("position", Vector3.ZERO) as Vector3) \
		+ Vector3(0.0, PODIUM.y * 0.22 + PANEL.y * 0.75, -PODIUM.z * 0.51)
	_pointer_marker.visible = true


## Testable rendering seam: applies only a complete native state vector for one known room.
func apply_room_state(room_id: StringName, values: PackedByteArray) -> bool:
	if not ROOMS.has(room_id) or values.size() != endpoint_count:
		return false
	var bank: Dictionary = _banks.get(room_id, {})
	var previous: PackedByteArray = bank.get("values", PackedByteArray()) as PackedByteArray
	var panels: MultiMeshInstance3D = bank.get("panels") as MultiMeshInstance3D
	if panels == null or panels.multimesh == null:
		return false
	var changed := false
	for index in range(values.size()):
		if previous.size() == values.size() and previous[index] == values[index]:
			continue
		panels.multimesh.set_instance_color(index, _panel_colour(room_id, values[index]))
		changed = true
	bank["values"] = values
	_banks[room_id] = bank
	return changed


func _draw_room(room_id: StringName) -> void:
	var centre := room_centre(room_id)
	add_child(_slab("Floor_%s" % room_id, Vector3(ROOM_HALF.x * 2.0 + WALL * 2.0, WALL, ROOM_HALF.z * 2.0 + WALL * 2.0),
		centre + Vector3(0.0, -WALL * 0.5, 0.0), Color(0.075, 0.09, 0.12)))
	var named: PackedStringArray = ["North", "South", "West", "East", "Ceiling"]
	var all_boxes := boxes(null)
	var found: int = 0
	for box in all_boxes:
		if StringName(box["room"]) != room_id:
			continue
		add_child(_slab("%s_%s" % [named[found], room_id], 2.0 * (box["half_extents"] as Vector3),
			box["position"], Color(0.17, 0.21, 0.27) if found < 4 else Color(0.24, 0.27, 0.32)))
		found += 1
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp_%s" % room_id
	lamp.position = centre + Vector3(0.0, ROOM_HALF.y - 0.5, 0.0)
	lamp.omni_range = 22.0
	lamp.light_energy = 2.2
	lamp.shadow_enabled = false
	add_child(lamp)


func _draw_endpoints(room_id: StringName, count: int) -> void:
	var places := endpoint_places(room_id, count)
	_draw_instanced("DeviceBodies_%s" % room_id, places, PODIUM, Color(0.15, 0.17, 0.20))
	var panel_places := PackedVector3Array()
	for place in places:
		panel_places.append(place + Vector3(0.0, PODIUM.y * 0.22, -PODIUM.z * 0.51))
	var panels := _draw_instanced("DevicePanels_%s" % room_id, panel_places, PANEL, Color.WHITE, true)
	var registry: Array[Dictionary] = []
	for index in range(count):
		registry.append({"room_id": room_id, "index": index, "device_id": "%s/%03d" % [room_id, index],
			"position": places[index], "revision": ROOM_CONTROL_REVISION})
	var zeros := PackedByteArray()
	zeros.resize(count)
	_banks[room_id] = {"registry": registry, "values": PackedByteArray(), "panels": panels}
	apply_room_state(room_id, zeros)


func _draw_instanced(named: String, places: PackedVector3Array, size: Vector3, colour: Color,
		use_colours := false) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.metallic = 0.35
	paint.roughness = 0.58
	paint.vertex_color_use_as_albedo = use_colours
	mesh.material = paint
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = use_colours
	instances.instance_count = places.size()
	instances.mesh = mesh
	for index in range(places.size()):
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, places[index]))
	var node := MultiMeshInstance3D.new()
	node.name = named
	node.multimesh = instances
	add_child(node)
	return node


func _make_pointer_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "DevicePointerMarker"
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 12
	mesh.rings = 6
	marker.mesh = mesh
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(1.0, 0.92, 0.28)
	paint.emission_enabled = true
	paint.emission = Color(1.0, 0.74, 0.10)
	paint.emission_energy_multiplier = 2.0
	marker.material_override = paint
	marker.visible = false
	return marker


func _draw_sign(room_id: StringName) -> void:
	var sign := Label3D.new()
	sign.name = "RoomSign_%s" % room_id
	sign.text = "ROOM %s  •  %d ENDPOINTS\nROOM-CONTROL BANK: OFFLINE" % [String(room_id).to_upper(), endpoint_count]
	sign.font_size = 64
	sign.pixel_size = 0.003
	sign.modulate = Color(0.32, 0.82, 0.96) if room_id == &"alpha" else Color(1.0, 0.51, 0.25)
	sign.position = room_centre(room_id) + Vector3(0.0, 2.3, -ROOM_HALF.z + 0.06)
	add_child(sign)


func _slab(named: String, size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = named
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 0.75
	node.material_override = paint
	return node


func _refresh_signs() -> void:
	for room_id in ROOMS:
		var sign := get_node_or_null("RoomSign_%s" % room_id) as Label3D
		if sign == null:
			continue
		sign.text = "ROOM %s  %d ENDPOINTS\nROOM-CONTROL BANK: %s" % [String(room_id).to_upper(), endpoint_count,
			"SYNCED" if room_control_online() else "OFFLINE"]


func _state_bytes(answer: Variant) -> PackedByteArray:
	if answer is PackedByteArray:
		return answer
	if not answer is Array:
		return PackedByteArray()
	var out := PackedByteArray()
	for value in answer as Array:
		if not (value is int or value is float):
			return PackedByteArray()
		var whole := int(value)
		if whole != float(value) or whole < 0 or whole > 255:
			return PackedByteArray()
		out.append(whole)
	return out


func _panel_colour(room_id: StringName, value: int) -> Color:
	var off := Color(0.12, 0.50, 0.63) if room_id == &"alpha" else Color(0.68, 0.30, 0.15)
	return off.lerp(Color(0.88, 1.0, 0.58), float(value) / 255.0)
