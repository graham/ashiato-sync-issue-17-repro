extends Node
## Windowed visual/cost probe for the shipping LevelMap and MapCanvas.
## Godot --xr-mode off --path cockpit res://tests/map_shot.tscn -- --out=...

var out_path := "res://screenshots/2026-09-16/map-item19-island.png"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--out="): out_path = String(arg).trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		print("[map_shot] RESULT=FAIL windowed renderer required")
		get_tree().quit(1); return
	_build_island()
	var chart := LevelChart.new(); chart.world = "island"
	var map := LevelMap.new(); add_child(map); map.configure(chart)
	var canvas := MapCanvas.new(); canvas.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(canvas)
	var rows: Array[Dictionary] = the_picture()
	var began := Time.get_ticks_usec()
	map.rebuild()
	await map.rebuilt
	var took_ms := float(Time.get_ticks_usec() - began) / 1000.0
	canvas.show_map(map, rows)
	# A MACHINE PICKED, not a person: picking is the only way an AI contact is named at all, and the
	# reader has to be able to see what that looks like beside the ones that are named always.
	canvas.selected_contact = -19
	canvas.queue_redraw()
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	var saved := image.save_png(absolute)
	# AND THE SAME PICTURE WITH THE COLOUR TAKEN OUT. Colour is one of the four channels and the only one
	# a colour-blind eye, a washed-out projector or a photocopy can lose; if a player and a machine cannot
	# be told apart here, the other three are not doing their share (team-lead, 2026-09-17: "reads in
	# greyscale is the test I would have asked for"). It is a picture and it has no assertion.
	var grey_path: String = absolute.get_basename() + "-greyscale.png"
	var grey := Image.create_from_data(image.get_width(), image.get_height(), false,
		image.get_format(), image.get_data())
	grey.adjust_bcs(1.0, 1.0, 0.0)
	var grey_saved := grey.save_png(grey_path)
	print("[map_shot] greyscale %s %s" % ["saved" if grey_saved == OK else "FAILED", grey_path])
	print("[map_shot] 1024px UPDATE_ONCE %.2f ms, %dx%d, %s" % [took_ms, image.get_width(), image.get_height(), absolute])
	var passed := saved == OK and map.texture() is ImageTexture
	print("[map_shot] frozen background %s" % ("present" if map.texture() is ImageTexture else "missing"))
	print("[map_shot] %s" % AirPicture.tally(rows))
	print("[map_shot] RESULT=%s" % ("PASS" if passed else "FAIL"))
	get_tree().quit(0 if passed else 1)

func _build_island() -> void:
	var sea := MeshInstance3D.new(); var sea_mesh := BoxMesh.new(); sea_mesh.size = Vector3(16000, 4, 16000)
	sea.mesh = sea_mesh; sea.position.y = -4; sea.material_override = _material(Color("164d72")); add_child(sea)
	var ground := MeshInstance3D.new(); var ground_mesh := BoxMesh.new(); ground_mesh.size = Vector3(14400, 2, 14400)
	ground.mesh = ground_mesh; ground.position.y = -1; ground.material_override = _material(Color("486b43")); add_child(ground)
	for box in Terrain.boxes():
		var half := box.get("half_extents", Vector3.ZERO) as Vector3
		if half == Vector3.ZERO: continue
		var shape := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = half * 2.0
		shape.mesh = mesh; shape.position = box["position"]
		var high := clampf((shape.position.y + half.y) / 700.0, 0.0, 1.0)
		shape.material_override = _material(Color("65744b").lerp(Color("b6afa0"), high))
		add_child(shape)

func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.albedo_color = colour; material.roughness = 1.0
	return material


## THE OPERATOR'S PICTURE: three people in the exercise and thirty-two machines round them, which is what
## the island really has in it, laid out so a reader can judge the one thing this feature is for -- can you
## tell, in a second, which three of the thirty-five have a person in them.
##
## HAND-BUILT, and it has to be: a probe drawing whatever the level happened to spawn is a probe whose
## picture means something different every run, and the question here is about the DRAWING. What the rows
## mean, and that they can only have come from the simulation's seats, is tests/air_picture.gd's.
##
## THE AIR PICTURE BOTH SHOTS DRAW: three people and thirty-two machines on a fixed spiral. Static and public so
## `plot_shot` puts the same contacts on the plot table as this puts on the flat map, and one picture is not two.
static func the_picture() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"contact": 1, "client": 1, "vehicle": 1, "kind": Sim.Kind.FIGHTER, "position": Vector3(-1400, 0, -1400),
			"heading": 0.75 * PI, "yours": true, "name": "MAGIC", "colour": PlayerColours.at(0),
			"distance": 0.0, "manned": true},
		{"contact": 2, "client": 2, "vehicle": 2, "kind": Sim.Kind.FIGHTER, "position": Vector3(3400, 0, -1200),
			"heading": PI, "yours": false, "name": "SLINGSHOT", "colour": PlayerColours.at(1),
			"distance": 4804.0, "manned": true},
		{"contact": 3, "client": 3, "vehicle": 3, "kind": Sim.Kind.HAWKEYE, "position": Vector3(-3600, 0, 300),
			"heading": 0.0, "yours": false, "name": "BULLDOG", "colour": PlayerColours.at(4),
			"distance": 2780.0, "manned": true}]
	# Thirty-two machines on a fixed spiral, so two runs of this probe draw the same picture and a change
	# in it is a change in the drawing.
	var kinds: Array[int] = [Sim.Kind.PLANE, Sim.Kind.AIRLINER, Sim.Kind.HELI, Sim.Kind.CESSNA, Sim.Kind.BOAT]
	for i in range(32):
		var turn: float = TAU * float(i) * 0.191
		var out: float = 900.0 + 190.0 * float(i)
		rows.append({"contact": -(10 + i), "client": -1, "vehicle": 10 + i, "kind": kinds[i % kinds.size()],
			"position": Vector3(cos(turn) * out, 0.0, sin(turn) * out * 0.82),
			"heading": turn + PI * 0.5, "yours": false,
			"name": AirPicture.callsign_of(kinds[i % kinds.size()], 10 + i),
			"colour": AirPicture.AI, "manned": false, "distance": out})
	return rows
