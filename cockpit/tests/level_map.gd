extends Node

var failures: PackedStringArray = []

func _check(label: String, okay: bool, detail: String) -> void:
	print("[level_map] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay: failures.append(label)

func _ready() -> void:
	var chart := LevelChart.new()
	chart.world = "island"
	var map := LevelMap.new()
	add_child(map)
	map.configure(chart)
	var corners := [Vector3(-Terrain.GROUND_HALF.x, 0, -Terrain.GROUND_HALF.z),
		Vector3(Terrain.GROUND_HALF.x, 0, -Terrain.GROUND_HALF.z),
		Vector3(-Terrain.GROUND_HALF.x, 0, Terrain.GROUND_HALF.z),
		Vector3(Terrain.GROUND_HALF.x, 0, Terrain.GROUND_HALF.z)]
	var expected := [Vector2(0, 0), Vector2(1024, 0), Vector2(0, 1024), Vector2(1024, 1024)]
	var worst := 0.0
	for i in range(corners.size()): worst = maxf(worst, map.to_map(corners[i]).distance_to(expected[i]))
	_check("the_camera_projects_the_four_world_corners_to_the_texture_corners", worst <= 1.0, "worst %.3f px" % worst)
	var craft := Vector3(1800, 300, -3600)
	_check("a_craft_pixel_is_its_x_and_z", map.to_map(craft).distance_to(Vector2(640, 256)) <= 1.0,
		"%s" % map.to_map(craft))
	map.rebuild()
	var after := map.render_count
	for i in range(5): await get_tree().process_frame
	_check("ordinary_frames_do_not_rebuild_the_dead_world", map.render_count == after and map.update_mode() != SubViewport.UPDATE_ALWAYS,
		"renders %d, mode %d" % [map.render_count, map.update_mode()])
	map.rebuild(); map.rebuild(); map.rebuild()
	_check("level_time_and_finish_triggers_can_each_request_one_rebuild", map.render_count == after + 3,
		"renders %d" % map.render_count)
	var old_roster := Net.roster
	Net.roster = {2: {"player": 2, "name": "MAVERICK", "colour": 3}}
	var rows := LevelMap.markers([{"vehicle": 7, "names": 2, "yours": true, "distance": 0.0}],
		{7: {"position": craft, "basis": Quaternion.IDENTITY}})
	_check("markers_are_derived_from_replicated_state", rows.size() == 1 and rows[0]["position"] == craft
		and rows[0]["name"] == "MAVERICK", str(rows))
	_check("marker_identity_comes_from_the_authoritative_net_roster",
		rows.size() == 1 and rows[0]["colour"] == Net.colour_of(2), str(rows))
	Net.roster = old_roster
	_finish()

func _finish() -> void:
	print("RESULT=PASS" if failures.is_empty() else "RESULT=FAIL %s" % ", ".join(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
