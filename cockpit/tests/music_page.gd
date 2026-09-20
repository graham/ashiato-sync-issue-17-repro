extends Node

var failures: Array[String] = []
func check(label: String, ok: bool, detail: String) -> void:
	print("[music_page] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)

func _ready() -> void:
	var page := ClipboardPage.new()
	add_child(page)
	page.show_music_catalog(["ride", "test_tone"])
	page.show_music({"track":"ride", "volume_to":-12.0}, "ride · 0:12 · 25%", true)
	page.show_tab(ClipboardPage.Tab.MUSIC)
	var music := page.music_page()
	var chosen: Array[String] = []
	page.chose_music.connect(func(id: String): chosen.append(id))
	var buttons := music.track_buttons()
	buttons[0].pressed.emit()
	check("a_real_track_button_announces_the_track", chosen == ["ride"], str(chosen))
	check("the_playing_track_and_position_are_shown", music.readout().contains("ride") and music.readout().contains("0:12"), music.readout())
	page.show_music({"track":"ride", "volume_to":-12.0}, "ride · 0:12 · 25%", false)
	check("a_joiners_track_controls_are_refused", music.track_buttons().all(func(button): return button.disabled),
		"disabled %s" % [music.track_buttons().map(func(button): return button.disabled)])
	check("the_ninth_tab_is_reachable_and_map_follows_it", page.tab() == ClipboardPage.Tab.MUSIC
		# NOT A COUNT OF TABS: this held `Tab.size() == 10`, a typed roster that went red when LOG made eleven
		# (lane/handshake, 2026-09-18). The order is what this check is about.
		and ClipboardPage.Tab.MAP == ClipboardPage.Tab.MUSIC + 1,
		"tab %d of %d" % [page.tab(), ClipboardPage.Tab.size()])
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
