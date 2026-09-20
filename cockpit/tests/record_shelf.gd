extends Node

var failures: Array[String] = []

func check(label: String, ok: bool, detail: String) -> void:
	print("[record_shelf] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)

func _ready() -> void:
	var editor := RecordShelf.folders(PackedStringArray(["--music=C:/asked"]), "C:/game/cockpit.exe", true,
		"res://music")
	check("the_command_line_folder_is_first", editor.size() == 3 and editor[0] == "C:/asked", str(editor))
	check("the_executable_music_folder_is_second", editor[1].replace("\\", "/") == "C:/game/music", str(editor))
	var exported := RecordShelf.folders(PackedStringArray(), "C:/game/cockpit.exe", false)
	check("an_export_never_reaches_back_into_the_project", exported.size() == 1, str(exported))
	check("ids_are_bounded_wire_values", RecordShelf.valid_id("ride_2-live") and not RecordShelf.valid_id("Ride.ogg")
		and not RecordShelf.valid_id("../ride"), RecordShelf.ID_PATTERN)
	var shelf := RecordShelf.new()
	add_child(shelf)
	shelf.scan(ProjectSettings.globalize_path("res://tests/music_fixtures"))
	check("a_good_ogg_is_loaded_by_its_file_name", shelf.ids() == ["test_tone"] and shelf.stream_for("test_tone") != null,
		"tracks %s" % [shelf.ids()])
	check("a_broken_ogg_is_disabled_and_an_underscore_file_is_skipped", shelf.disabled.has("bad name")
		and not shelf.disabled.has("_skip") and shelf.stream_for("_skip") == null, "disabled %s" % [shelf.disabled])
	var state := {"started_frame": 120.0, "fade_from_frame": 120.0, "fade_frames": 600.0,
		"volume_from": -60.0, "volume_to": -10.0}
	check("playback_uses_the_shared_frame_and_wraps", is_equal_approx(MusicBox.playback_offset(state, 420.0, 120.0, 2.0), 0.5),
		"offset %.3f" % MusicBox.playback_offset(state, 420.0, 120.0, 2.0))
	check("a_fade_is_a_pure_function_of_the_shared_frame", is_equal_approx(MusicBox.volume_db_at(state, 420.0), -35.0),
		"volume %.2f" % MusicBox.volume_db_at(state, 420.0))
	var old_music := Net.music_state
	Net.music_state = {"track":"test_tone", "started_frame":MusicBox.server_frame(), "volume_from":-12.0,
		"volume_to":-12.0, "fade_from_frame":MusicBox.server_frame(), "fade_frames":0.0, "music_n":1}
	var box := MusicBox.new()
	box.shelf = shelf
	add_child(box)
	var wall := Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall < 400:
		await get_tree().process_frame
	check("the_dummy_audio_driver_advances_runtime_ogg_playback", box.player.playing and box.player.get_playback_position() > 0.1,
		"playing %s at %.3f s" % [box.player.playing, box.player.get_playback_position()])
	box.queue_free()
	Net.music_state = old_music
	var good := Net.read_hello(JSON.stringify({"say":"music", "music":"test_tone", "music_started":120.0,
		"music_from":-60.0, "music_to":-10.0, "music_fade_at":120.0, "music_fade_frames":600.0,
		"music_n":2}).to_utf8_buffer())
	check("a_music_document_is_validated", good.get("music") == "test_tone" and good.get("music_n") == 2, str(good))
	var bad := Net.read_hello(JSON.stringify({"say":"music", "music":"../bad", "music_started":-1,
		"music_from":20, "music_to":-10, "music_fade_at":0, "music_fade_frames":0, "music_n":2}).to_utf8_buffer())
	check("a_malformed_music_document_is_dropped", bad.is_empty(), str(bad))
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
