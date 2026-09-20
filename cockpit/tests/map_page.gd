extends Node

var failures: PackedStringArray = []
func _check(label: String, okay: bool, detail: String) -> void:
	print("[map_page] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay: failures.append(label)

func _ready() -> void:
	var chart := LevelChart.new(); chart.world = "island"
	var map := LevelMap.new(); add_child(map); map.configure(chart); map.rebuild()
	var page := MapCanvas.new(); page.size = Vector2(800, 600); add_child(page)
	var rows: Array[Dictionary] = [
		{"contact": 1, "client": 1, "vehicle": 11, "position": Vector3.ZERO, "heading": 0.0, "yours": true,
			"name": "PLAYER 1", "colour": Color.RED, "distance": 0.0, "manned": true},
		{"contact": 2, "client": 2, "vehicle": 12, "position": Vector3(3600, 0, -3600), "heading": PI * 0.5,
			"yours": false, "name": "PLAYER 2", "colour": Color.BLUE, "distance": 5091.0, "manned": true}]
	page.show_map(map, rows)
	await get_tree().process_frame
	var expected := map.to_map(rows[1]["position"]) * Vector2(800.0 / 1024.0, 600.0 / 1024.0)
	_check("both_arrows_land_on_level_map_pixels", page.marker_centres.size() == 2
		and (page.marker_centres[2] as Vector2).distance_to(expected) < 1.0, str(page.marker_centres))
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = expected
	page._gui_input(click)
	_check("pressing_a_marker_highlights_it", page.selected_contact == 2, "selected %d" % page.selected_contact)
	_check("the_page_fits_the_clipboard_body", page.custom_minimum_size.x <= 800 and page.size.y <= 600,
		"size %s minimum %s" % [page.size, page.custom_minimum_size])
	_finish()

func _finish() -> void:
	print("RESULT=PASS" if failures.is_empty() else "RESULT=FAIL %s" % ", ".join(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
