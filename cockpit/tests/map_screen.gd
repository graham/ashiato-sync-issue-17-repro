extends Node

var failures: PackedStringArray = []
func _check(label: String, okay: bool, detail: String) -> void:
	print("[map_screen] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay: failures.append(label)

func _ready() -> void:
	var screen := ControlCatalogue.make(&"MapScreen") as MapScreen
	add_child(screen); screen.setup(0)
	var chart := LevelChart.new(); chart.world = "island"
	var map := LevelMap.new(); add_child(map); map.configure(chart); map.rebuild()
	var rows: Array[Dictionary] = [{"client": 3, "position": Vector3(1000, 0, 2000), "heading": 0.2,
		"yours": false, "name": "PLAYER 3", "colour": Color.GREEN, "distance": 3000.0}]
	screen.show_map(map, rows)
	await get_tree().process_frame
	var canvas := screen.map_canvas()
	_check("map_screen_is_a_builder_part_with_a_decided_gesture", ControlCatalogue.has(&"MapScreen")
		and screen.taken_by() == Bind.Take.NONE, "take %d" % screen.taken_by())
	_check("the_cockpit_screen_uses_the_same_marker_surface", canvas != null and canvas.markers == rows,
		"markers %d" % (canvas.markers.size() if canvas != null else -1))
	_check("the_cockpit_surface_keeps_the_level_picture_not_only_the_markers",
		canvas != null and canvas.background_texture() == map.texture(),
		"background %s" % ("present" if canvas != null and canvas.background_texture() != null else "missing"))
	var renders := map.render_count
	for i in range(5): await get_tree().process_frame
	_check("the_background_does_not_rebuild_with_the_overlay", map.render_count == renders,
		"renders %d" % map.render_count)
	_finish()

func _finish() -> void:
	print("RESULT=PASS" if failures.is_empty() else "RESULT=FAIL %s" % ", ".join(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
