extends Node
## ONE SEAT, FROM THE EYES OF WHOEVER IS SITTING IN IT, saved as a PNG.
##
##   Godot --path cockpit res://tests/station_shot.tscn -- --kind=gunship --seat=1
##   Godot --path cockpit res://tests/station_shot.tscn -- --kind=heli --seat=2 --craft
##   Godot --path cockpit res://tests/station_shot.tscn -- --kind=plane --seat=0 --add=TimeOfDayDial --time=evening --labels
##   Godot --path cockpit res://tests/station_shot.tscn -- --kind=fighter --seat=0 --craft --crew
##
## NOT HEADLESS -- it renders. Headless has no rendering device, so the viewport texture
## comes back empty and the file is a black rectangle that looks like a broken cockpit.
##
## Exists because a control can be in exactly the right place and still be wrong, and no
## assertion catches that. A trigger whose blade is on the far side of its own housing is
## bolted 30 cm forward at hand height, passes every check about where it is, and cannot be
## seen by the only person who will ever reach for it. The tests say where things ARE; this
## says what they LOOK LIKE, which is a different question and the one a cockpit is judged
## by. See racer/tests/shot.gd, which is the same idea for a car.
##
## The camera sits at the eye height the station is laid out around, looking the way the
## occupant looks. Anything it cannot see is something the occupant cannot see.
##
## `--craft` BUILDS THE WHOLE AIRCRAFT round the seat instead of the station on its own,
## with the airframe taken away exactly as it is for anybody sitting inside one. A station
## by itself is the right picture for a cockpit, where everything in front of the crew
## belongs to the seat -- and the wrong one for a seat whose main object belongs to the
## VEHICLE. A door gunner's gun is drawn by the hull, because everybody outside can see it
## too, so without this the gunner's seat photographs as a trigger floating in mid-air.

const OUT := "user://station.png"
const MapFixture := preload("res://tests/map_fixture.gd")
## THE AIR PICTURE `map_shot` DRAWS, for `--traffic`: the same three people and thirty-two machines, so the
## plot table and the flat map are photographed showing one picture rather than two.
const MapShot := preload("res://tests/map_shot.gd")


func _ready() -> void:
	# The station room deliberately has no level scenery. Supply map-only terrain
	# so a fitted MapScreen is judged with its real background, not an empty world.
	MapFixture.add_island(self)
	var kind: int = Sim.Kind.GUNSHIP
	var seat: int = 1
	var pitch: float = 0.0
	var yaw: float = 0.0
	var fov: float = 75.0
	# A GUN WITH THE FINGER ON IT, so the blade can be checked where it matters.
	var pulled: bool = false
	# EVERY CONTROL SAYING WHAT IT IS, which is a thing to LOOK at rather than assert: a
	# label can be correct, attached to the right control, and still sit inside the lever
	# next to it or behind the panel.
	var labels: bool = false
	# The whole aircraft round the seat, rather than the station on its own.
	var whole_craft: bool = false
	# A PART FROM THE BUILDER'S BIN, put where the builder lands one, so a part no cockpit is built with can be looked at.
	var adding: StringName = &""
	# THE WHOLE AIR PICTURE on every map glass rather than one crewed marker -- what a flag plot's table is for.
	var traffic: bool = false
	# WHERE THE PICTURE GOES, and whether a copy with the colour taken out goes beside it. The greyscale copy
	# is the test of the plot's four channels: if a person and a machine cannot be told apart there, colour is
	# doing all the work (see `map_shot`, which saves the same pair for the flat map).
	var out: String = OUT
	var greyscale: bool = false
	# A CREW ON THE CREW BOARD: you in this seat and a player in every other one, because nothing is running to say who
	# sits where, and an empty board is not the board anybody will look at.
	var crewed: bool = false
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--kind="):
			var wanted: String = text.substr(7).to_upper()
			if wanted in Sim.Kind.keys():
				kind = Sim.Kind[wanted]
		elif text.begins_with("--seat="):
			seat = int(text.substr(7))
		elif text.begins_with("--pitch="):
			pitch = deg_to_rad(float(text.substr(8)))
		elif text.begins_with("--yaw="):
			yaw = deg_to_rad(float(text.substr(6)))
		elif text.begins_with("--fov="):
			fov = float(text.substr(6))
		elif text.begins_with("--pulled"):
			pulled = true
		elif text.begins_with("--labels"):
			labels = true
		elif text.begins_with("--craft"):
			whole_craft = true
		elif text.begins_with("--add="):
			adding = StringName(text.substr(6))
		elif text.begins_with("--traffic"):
			traffic = true
		elif text.begins_with("--out="):
			out = text.substr(6)
		elif text.begins_with("--greyscale"):
			greyscale = true
		elif text.begins_with("--crew"):
			crewed = true

	# A LIT ROOM AND NOTHING ELSE. No sky, no aeroplane, no physics: the question is what
	# one station looks like from one seat, and everything else in the world is a way for
	# that question to be answered by accident.
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	light.light_energy = 1.2
	add_child(light)
	var fill := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.40, 0.46)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.ambient_light_energy = 1.0
	fill.environment = env
	add_child(fill)

	# THE SEAT, AND -- IF ASKED -- THE AIRCRAFT ROUND IT. Both end with `station` being the
	# thing in front of the occupant and `here` being the node their eyes are in, so
	# everything below is written once.
	var station: CockpitStation = null
	var here: Node = self
	if whole_craft:
		var view := (load("res://objects/vehicles/craft_%s.tscn" % Sim.kind_name(kind))
			as PackedScene).instantiate() as VehicleView
		add_child(view)
		view._show_in_editor()
		# TAKEN AWAY, because the occupant is inside it. See VehicleView._show_body: a
		# fuselage drawn solid from within is a wall between the eye and everything.
		view._show_body(true)
		for one in view.stations():
			if (one as CockpitStation).seat == seat:
				station = one as CockpitStation
		here = view.seat_anchor(seat)
		# AND THE GUN POINTED WHERE IT RESTS. Nothing is running, so nobody has published a
		# turret angle: the mounts start at the gun's own rest angles -- which is what a
		# gunner sees on climbing aboard -- and this is that same table.
		var aims: Array = []
		for mount in range(3):
			aims.append((Sim.gun_of(kind, mount).get("rest", Vector2.ZERO)) as Vector2)
		view.draw_turrets_at(aims)
	else:
		station = (VehicleCatalogue.seat_scene(kind).instantiate()) as CockpitStation
		add_child(station)
		station.fit(seat, _flies(kind, seat), kind)
	await get_tree().process_frame
	if pulled:
		var gun := station.controls().get("trigger") as VehicleControl
		if gun != null:
			gun.hand_input(Bind.TRIGGER, true)

	if adding != &"":
		var made: VehicleControl = ControlCatalogue.make(adding)
		if made == null:
			push_warning("[station] no part called %s" % adding)
		else:
			made.name = String(adding)
			station.add_child(made)
			made.setup(seat)
			PilotRig.place_a_new_control(station, made)
	# AND THE TIME OF DAY, on any dial that shows one, as `--time=` asks: there is no level here to tell it.
	var time: float = Daylight.asked_on_the_command_line()
	for child in station.get_children():
		if child is TimeOfDayDial:
			(child as TimeOfDayDial).show_time(time)

	if labels:
		for child in station.get_children():
			var control := child as VehicleControl
			if control != null:
				control.show_label(true)

	# A fitted map screen gets the same dead picture and live marker surface it
	# receives in FlightLevel, so station gallery shots never show an unexplained
	# black pane merely because this visual probe has no running simulation.
	var chart := LevelChart.new()
	chart.world = "island"
	var level_map := LevelMap.new()
	add_child(level_map)
	level_map.configure(chart)
	level_map.rebuild()
	var markers: Array[Dictionary] = [{"client": 2, "position": Vector3(1800, 0, -2200),
		"heading": 0.6, "yours": false, "name": "PLAYER 2", "colour": Color("ffbd59"),
		"distance": 2840.0}]
	if traffic:
		markers = MapShot.the_picture()
	# WAITED FOR, as `map_shot` waits: the glass is handed a map whose background has finished drawing.
	await level_map.rebuilt
	station.show_map(level_map, markers)
	if crewed:
		var crew: Array = []
		var poses: Array = Sim.geometry_of(kind).get("seat_poses", [])
		for i in range(poses.size()):
			crew.append({"seat": i, "station": String((poses[i] as Dictionary).get("station", "?")),
				"client": i + 2, "mine": i == seat})
		station.show_crew(crew)

	var eye := Camera3D.new()
	# WHERE THE OCCUPANT'S EYES ARE, which is the height the whole station is laid out
	# around -- see CockpitStation.EYE_HEIGHT -- above the seat anchor, which is the play
	# space FLOOR and not the seat pan.
	eye.position = Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	eye.rotation = Vector3(pitch, yaw, 0.0)
	eye.fov = fov
	eye.near = 0.02
	here.add_child(eye)
	eye.current = true

	# WHAT IS IN FRONT OF THE FACE, in words, beside the picture. A screenshot says a
	# control looks wrong; this says which control and where, so the next person does not
	# have to measure it off the image.
	print("[station] %s seat %d" % [Sim.kind_name(kind), seat])
	for child in station.get_children():
		var control := child as VehicleControl
		if control == null:
			continue
		var grip: Vector3 = station.to_local(control.grip_global())
		print("[station]   %-9s at %6.2f %6.2f %6.2f, grip %6.2f %6.2f %6.2f, facing %s"
			% [control.name, control.position.x, control.position.y, control.position.z,
				grip.x, grip.y, grip.z, _facing(control)])

	for i in range(4):
		await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	var absolute: String = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var err: int = shot.save_png(absolute)
	print("[station] %s -> %s" % ["saved" if err == OK else "FAILED", absolute])
	if greyscale and err == OK:
		var grey := Image.create_from_data(shot.get_width(), shot.get_height(), false,
			shot.get_format(), shot.get_data())
		grey.adjust_bcs(1.0, 1.0, 0.0)
		var grey_path: String = absolute.get_basename() + "-greyscale.png"
		err = grey.save_png(grey_path)
		print("[station] greyscale %s -> %s" % ["saved" if err == OK else "FAILED", grey_path])
	get_tree().quit(0 if err == OK else 1)


## WHICH WAY A CONTROL'S GRIP LIES FROM ITS OWN ORIGIN, in the occupant's words. The seat
## faces -Z, so a grip at -Z is on the far side of the control from the person reaching for
## it -- which is the difference between a trigger you can see and one you cannot.
func _facing(control: VehicleControl) -> String:
	var grip: Vector3 = control.grip_global() - control.global_position
	if absf(grip.z) < 0.005 and absf(grip.y) < 0.005 and absf(grip.x) < 0.005:
		return "its own origin"
	if absf(grip.z) >= absf(grip.y) and absf(grip.z) >= absf(grip.x):
		return "AWAY from the seat" if grip.z < 0.0 else "toward the seat"
	if absf(grip.y) >= absf(grip.x):
		return "above" if grip.y > 0.0 else "below"
	return "to the right" if grip.x > 0.0 else "to the left"


## WHETHER THIS SEAT FLIES, asked of the pose's own `flies` rather than worked out from its station word.
## This read "anything that is not a turret flies", which photographed every OPERATOR with a pilot's map
## pane in front of it instead of the two MFDs the game really fits there (lane/awacs, 2026-09-17).
func _flies(kind: int, seat: int) -> bool:
	var poses: Array = Sim.geometry_of(kind).get("seat_poses", []) as Array
	return bool((poses[seat] as Dictionary).get("flies", true)) if seat < poses.size() else true
