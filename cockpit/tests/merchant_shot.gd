extends Node3D
## THE MERCHANT SHIPS, LOOKED AT, before their kinds exist in the simulation.
##
##   Godot --xr-mode off --path cockpit --resolution 1600x900 res://tests/merchant_shot.tscn -- --out=C:/somewhere
##   ... -- --ships=crude_carrier --shots=side,plan,bow,reference,beside_the_ford,helm
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md).
##
## WHY IT IS NOT `ship_shot`. That one asks the level for a craft of a kind and photographs what the game drew. These ships
## have no kind yet -- they are `CrudeCarrierDraft` and `FerryDraft` until the C++ is scheduled -- so nothing places them and
## `Sim.current` never holds one. This builds the same node `VehicleView` would (`ShipHull.dress`) and stands it in a plain
## studio: a sky, one sun, and a flat sea at y = 0, which is where the shape says its waterline is. It is evidence about the
## MODEL, not about the game's sea, its finishes or its fog; when the kinds land, `ship_shot` photographs them at sea and
## that is what replaces these.
##
## THE ORTHOGRAPHIC SHOTS ARE FOR OVERLAYING ON THE REFERENCES: `side` and `plan` are true elevations on a stated datum --
## the waterline and midships -- so a photograph scaled to the same length can be laid over them. `reference` is a
## perspective camera put where the reference photograph's was, to the angle and the field measured in sources.md.
## `beside_the_ford` stands the ship alongside the carrier, which is the one thing in the game everybody already knows the
## size of.
##
## Pictures in `--out`: `cockpit-NN-<lane>-<ship>-<shot>.png`, NN being `--number=` and <lane> the checkout the
## run is in (or `--lane=`).

const SETTLE: int = 8
## The sea's colour and the sky's, near enough the game's to judge a hull against, and flat: this is a drawing, not weather.
const SEA := Color(0.10, 0.20, 0.28)
const SKY_TOP := Color(0.32, 0.46, 0.62)
const SKY_LOW := Color(0.62, 0.70, 0.78)
## How much of the frame the ship's box fills in the orthographic shots.
const FILL: float = 0.88
## THE REFERENCE VIEW, from craft/crude_carrier/sources.md: photograph P4 is from nearly dead ahead, 20.2 degrees above the
## water, about 9 degrees off the bow, and far enough for a telephoto -- a narrow field from a long way off.
const REFERENCE: Dictionary = {
	"crude_carrier": {"elevation": 20.2, "around": 9.0, "fov": 12.0, "range": 1400.0},
	"ferry": {"elevation": 12.0, "around": 20.0, "fov": 14.0, "range": 900.0},
	# THE BROADSIDE'S OWN GEOMETRY, from craft/destroyer/sources.md: B7 is beam-on at a small elevation, which is why it
	# could be scaled at all. Looking at the model the same way is what makes the picture comparable to the reference.
	"destroyer": {"elevation": 6.0, "around": 90.0, "fov": 14.0, "range": 1100.0},
	# THE TWO CONTAINER SHIPS HAVE NO REFERENCE PHOTOGRAPH, and their `reference` shot is therefore NOT an overlay and must
	# not be read as one. The KCS is a published hull form that was never built, and the Triple-E's figures came off an
	# infobox rather than off a picture measured here (craft/container_ship/sources.md). These are three-quarter views
	# chosen to show the arrangement -- the feeder's single island aft, the Triple-E's house forward and funnels far aft --
	# which is what a reader of these two pictures actually needs to tell them apart. `side` and `plan` remain true
	# elevations on the waterline and midships, so a drawing scaled to the same length could still be laid over them.
	"container_feeder": {"elevation": 12.0, "around": 38.0, "fov": 16.0, "range": 700.0},
	"container_large": {"elevation": 14.0, "around": 38.0, "fov": 16.0, "range": 1150.0},
	# THE FOUR SMALL CRAFT, from much closer and a little above -- the angle somebody standing on a pontoon gets, which
	# is where these boats will actually be seen from. No reference photograph for any of them either (see
	# craft/small_craft/sources.md), so these are not overlays; `side` and `plan` remain true elevations.
	"cruising_sloop": {"elevation": 14.0, "around": 42.0, "fov": 22.0, "range": 46.0},
	"classic_cutter": {"elevation": 14.0, "around": 42.0, "fov": 22.0, "range": 34.0},
	"stern_trawler": {"elevation": 16.0, "around": 42.0, "fov": 22.0, "range": 80.0},
	"motor_yacht": {"elevation": 15.0, "around": 42.0, "fov": 22.0, "range": 56.0},
}

var _failures: PackedStringArray = []
var _out: String = ""
var _number: String = "00"
## THE LANE THE PICTURE WAS TAKEN IN, which used to be the literal string "fleet3" whatever lane was running. Three
## lanes have now renamed these files on copy, which is a tax with no payer, so it is taken from the CHECKOUT the run
## is in: a worktree named seaport gives "seaport" and the shared checkout gives its own folder name. Override with
## `--lane=` after the bare --.
var _lane: String = ""
var _ships: PackedStringArray = ["crude_carrier", "ferry", "destroyer"]
var _shots: PackedStringArray = ["side", "plan", "bow", "reference", "beside_the_ford", "helm"]
var _camera: Camera3D = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[merchant_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--ships="):
			_ships = argument.trim_prefix("--ships=").split(",")
		elif argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=").split(",")
		elif argument.begins_with("--number="):
			_number = argument.trim_prefix("--number=")
		elif argument.begins_with("--lane="):
			_lane = argument.trim_prefix("--lane=")
	if _lane == "":
		_lane = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().get_file()
	if _out == "":
		var repo: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		_out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system())
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_studio()
	for ship_name in _ships:
		await _photograph(ship_name)
	_finish()


## THE STUDIO: a flat sea at the waterline, a sky, and one sun low enough to give a hull its sides.
func _studio() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = SKY_TOP
	sky.sky_horizon_color = SKY_LOW
	sky.ground_bottom_color = SEA
	sky.ground_horizon_color = SEA
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, 40.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000.0, 6000.0)
	sea.mesh = plane
	var water := StandardMaterial3D.new()
	water.albedo_color = SEA
	water.roughness = 0.25
	sea.material_override = water
	add_child(sea)
	_camera = Camera3D.new()
	_camera.far = 20000.0
	add_child(_camera)
	_camera.make_current()


## ONE SHIP, IN EVERY SHOT ASKED FOR.
func _photograph(ship_name: String) -> void:
	var geometry: Dictionary = _geometry_of(ship_name)
	if geometry.is_empty():
		_check("%s_has_a_draft" % ship_name, false, "no draft table")
		return
	var ship: Node3D = ShipHull.dress(-1, geometry)
	if ship == null:
		_check("%s_is_drawn" % ship_name, false, "ShipHull.dress built nothing")
		return
	add_child(ship)
	var box: AABB = _drawn_bounds(ship)
	print("[merchant_shot] %s: %.1f m long, %.1f m in the beam, %.1f m from keel to masthead" % [ship_name, box.size.z,
		box.size.x, box.size.y])
	var ford: Node3D = null
	var fleet: Array = []
	for shot in _shots:
		match shot:
			"side":
				# A SAILING BOAT IS TALLER THAN SHE IS LONG, and the old 3x height allowance framed one at a third of
				# the size. The cutter is 9.1 m long and 14.5 m keel to masthead, so 3x her height is 43.5 m of frame
				# for a 9 m boat. At 1.1x the mast fills the picture and the ships are untouched, their lengths
				# dominating either way (the tanker 332 m against 66).
				_orthographic(box, Vector3(1.0, 0.0, 0.0), Vector3.UP, maxf(box.size.z, box.size.y * 1.1))
			"plan":
				_orthographic(box, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, box.size.z)
			"bow":
				_orthographic(box, Vector3(0.0, 0.0, -1.0), Vector3.UP, maxf(box.size.x, box.size.y * 1.6))
			"reference":
				_like_the_photograph(ship_name, box)
			"beside_the_ford":
				ford = _the_ford(box)
				if ford == null:
					continue
			"helm":
				_from_the_helm(geometry)
			"liveries":
				fleet = _a_fleet_of_liveries(ship_name, geometry, box)
		await _frames(SETTLE)
		var path: String = _out.path_join("cockpit-%s-%s-%s-%s.png"
			% [_number, _lane, ship_name.replace("_", "-"), shot])
		var saved: bool = get_viewport().get_texture().get_image().save_png(path) == OK
		_check("%s_%s_is_saved" % [ship_name, shot], saved, path)
		if ford != null:
			ford.queue_free()
			ford = null
			await _frames(1)
		for extra in fleet:
			(extra as Node3D).queue_free()
		if not fleet.is_empty():
			fleet.clear()
			await _frames(1)
	ship.queue_free()
	await _frames(1)


## THE DRAFT TABLES, until each is a kind and this asks `Sim.geometry_of`.
func _geometry_of(ship_name: String) -> Dictionary:
	match ship_name:
		"crude_carrier":
			return CrudeCarrierDraft.geometry()
		"ferry":
			return FerryDraft.geometry()
		"destroyer":
			return DestroyerDraft.geometry()
		"container_feeder", "container_large":
			return ContainerShipDraft.geometry(ship_name)
		"cruising_sloop", "classic_cutter", "stern_trawler", "motor_yacht":
			return SmallCraftDraft.geometry(ship_name)
		_:
			return {}


## AN ELEVATION: the camera outside the ship looking along `from`, with the box fitted across `span`.
func _orthographic(box: AABB, from: Vector3, up: Vector3, span: float) -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = span / FILL
	var middle: Vector3 = box.get_center()
	_camera.global_position = middle + from * (box.size.length() + 500.0)
	_camera.look_at(middle, up)


## THE CAMERA WHERE THE REFERENCE PHOTOGRAPH'S WAS, so the two can be put side by side.
func _like_the_photograph(ship_name: String, box: AABB) -> void:
	var how: Dictionary = REFERENCE.get(ship_name, REFERENCE["crude_carrier"])
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = float(how["fov"])
	var around: float = deg_to_rad(float(how["around"]))
	var up: float = deg_to_rad(float(how["elevation"]))
	var range_off: float = float(how["range"])
	var middle: Vector3 = box.get_center()
	var way := Vector3(sin(around) * cos(up), sin(up), -cos(around) * cos(up))
	_camera.global_position = middle + way * range_off
	_camera.look_at(middle, Vector3.UP)


## THE FORD ALONGSIDE, three hundred metres off, for scale: the carrier as the game itself draws it.
func _the_ford(box: AABB) -> Node3D:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.CARRIER)
	if (geometry.get("parts", []) as Array).is_empty():
		_check("the_ford_is_there_to_stand_beside", false, "no carrier geometry; is the extension loaded?")
		return null
	var ford: Node3D = ShipHull.dress(Sim.Kind.CARRIER, geometry)
	if ford == null:
		return null
	add_child(ford)
	ford.global_position = Vector3(320.0, 0.0, 0.0)
	var middle: Vector3 = box.get_center()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 45.0
	_camera.global_position = middle + Vector3(160.0, 260.0, -700.0)
	_camera.look_at(Vector3(160.0, 0.0, 0.0), Vector3.UP)
	return ford


## FROM THE HELM: the pilot's eye, looking down the ship at its bow.
func _from_the_helm(geometry: Dictionary) -> void:
	var eye := Vector3(0.0, 2.0, 0.0)
	for entry in (geometry.get("seat_poses", []) as Array):
		if bool(entry.get("flies", false)):
			eye = (entry["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
			break
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 70.0
	_camera.global_position = eye
	_camera.look_at(Vector3(0.0, 0.0, -(geometry.get("extents", Vector3.ONE) as Vector3).z), Vector3.UP)


## THE DRAWN BOX of a ship node, from the vertices of every mesh under it, in the ship's own frame.
func _drawn_bounds(ship: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for node in ship.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var one: AABB = mesh_node.mesh.get_aabb()
		box = one if first else box.merge(one)
		first = false
	return box


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()


## SIX OF ONE VESSEL IN SIX LIVERIES, ranged alongside each other -- the picture the user asked for, so that a fleet can
## be seen to be a fleet rather than a photocopy.
##
## THE SHIP ALREADY IN THE SCENE IS LIVERY 0 and is moved to the head of the line rather than hidden, so that what is
## photographed is the same node every other shot in this run photographed. Adding a seventh copy and leaving the first
## standing at the origin is how a line of six becomes a line of seven with one in the wrong place.
##
## Returns the extra nodes so the caller frees them; they must not outlive the shot.
func _a_fleet_of_liveries(ship_name: String, geometry: Dictionary, box: AABB) -> Array:
	var count: int = ShipHull.livery_count(ship_name)
	var made: Array = []
	# Beam and a half between hulls: close enough to compare a colour against its neighbour, far enough not to touch.
	var step: float = box.size.x * 1.5
	var first: float = -step * float(count - 1) * 0.5
	var ship: Node3D = get_node_or_null("Ship") as Node3D
	if ship != null:
		ship.position = Vector3(first, 0.0, 0.0)
	for livery in range(1, count):
		var other: Node3D = ShipHull.dress(-1, geometry, livery)
		if other == null:
			continue
		other.position = Vector3(first + step * float(livery), 0.0, 0.0)
		add_child(other)
		made.append(other)
	# LOOKED AT FROM ABEAM AND A LITTLE ABOVE, far enough off that all six are in the frame: the whole line is
	# `count` hulls and their gaps across, and the camera is fitted to THAT rather than to one ship.
	var across: float = step * float(count - 1) + box.size.x
	var high: float = box.size.y
	# THE SHIP'S OWN LENGTH COMES TOWARDS THE CAMERA and has to be cleared as well as the width of the line. Fitted to
	# the line alone, a 235 m feeder's nearest bow stands 197 m from a camera 315 m from the middle, and six of them
	# burst the frame at both edges.
	var range: float = maxf(across, box.size.z) * 1.15 + box.size.z * 0.6
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 34.0
	# LOW ENOUGH TO SEE TOPSIDES. At 30 degrees down the line reads as six decks, and a deck is the one part of a
	# boat a livery barely touches -- the hull colour is the subject and it is on the SIDE. At 17 degrees the
	# topsides carry the picture and the cove line along the sheer is legible, which is what says one boat from the
	# next at a distance.
	_camera.position = Vector3(0.0, high * 0.35 + range * 0.14, range)
	_camera.look_at(Vector3(0.0, high * 0.32, 0.0), Vector3.UP)
	return made
