extends Node
## Real ENet proof: only the host owns Kokoro; host and model-free client play
## the same decoded long-message clip.

const FIRST_PORT := 48120
const PORTS := 6
const WAIT_MSEC := 30000
var failures: Array[String] = []
var child_pid: int = 0

func check(label: String, ok: bool, detail: String) -> void:
	print("[radio_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)

func args() -> PackedStringArray:
	var all := OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_args():
		if not all.has(arg): all.append(arg)
	return all

func value(prefix: String, fallback: String = "") -> String:
	for arg in args():
		if arg.begins_with(prefix): return arg.substr(prefix.length())
	return fallback

func _ready() -> void:
	if args().has("--radio-child"): await _child()
	else: await _parent()

func _child() -> void:
	var empty := ProjectSettings.globalize_path("user://radio_no_models")
	DirAccess.make_dir_recursive_absolute(empty); OS.set_environment(PilotHeadphones.MODELS_VARIABLE, empty)
	Headphones.extension_path = "user://missing_kokoro.gdextension"
	Net.session_ready.connect(func(): Net.level_loaded(""))
	Net.join("127.0.0.1", int(value("--join=", str(TestPorts.of(FIRST_PORT)))))
	var played := [0]
	Radio.clip_played.connect(func(_id: int, samples: int, _peer: int): played[0] = samples)
	var since := Time.get_ticks_msec()
	while not Net.is_in_session and Time.get_ticks_msec() - since < WAIT_MSEC: await get_tree().physics_frame
	Headphones.choose_voice(true)
	var refusal := Radio.publish_pcm(PackedFloat32Array([0.0, 0.1]), RadioClip.RATE)
	while played[0] == 0 and Time.get_ticks_msec() - since < WAIT_MSEC: await get_tree().physics_frame
	print("RADIO_CHILD samples=%d clips=%d voice=%s no_model=%s refusal=%s" % [played[0], Headphones.played_clips,
		Headphones.said.replace(" ", "_"), not Headphones.why_there_is_no_voice().is_empty(), refusal.replace(" ", "_")])
	get_tree().quit(0 if played[0] > 0 else 1)

func _parent() -> void:
	# THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently: hunting by calling `Net.host` until one
	# worked printed "ERROR: Couldn't create an ENet host." for every held port, and the runner's error gate fails that.
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	if port != 0:
		Net.host(port)
	check("the_host_opens_a_real_enet_session", Net.is_in_session,
		"port %d" % port if port != 0 else TestPorts.busy(FIRST_PORT, PORTS))
	if not Net.is_in_session: _finish(); return
	Net.level_loaded("")
	var child_log := ProjectSettings.globalize_path(TestPorts.log_for("radio_peers", "child"))
	if FileAccess.file_exists(child_log): DirAccess.remove_absolute(child_log)
	child_pid = OS.create_process(OS.get_executable_path(), PackedStringArray(["--headless", "--xr-mode", "off", "--desktop-only",
		"--fixed-fps", "120", "--log-file", child_log, "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/radio_peers.tscn", "--", "--radio-child", "--join=%d" % port]))
	var since := Time.get_ticks_msec()
	while Net.admitted.is_empty() and Time.get_ticks_msec() - since < WAIT_MSEC: await get_tree().physics_frame
	check("the_model_free_joiner_is_admitted", not Net.admitted.is_empty(), str(Net.admitted.keys()))
	Headphones.choose_voice(true)
	while Headphones.voice != PilotHeadphones.Voice.ON and Time.get_ticks_msec() - since < WAIT_MSEC:
		await get_tree().process_frame
	check("the_host_model_loads", Headphones.voice == PilotHeadphones.Voice.ON, Headphones.said)
	var page := ClipboardPage.new(); add_child(page); await get_tree().process_frame
	var spoke := ["button did not emit"]
	page.chose_radio.connect(func(text: String): spoke[0] = Radio.speak(text))
	var speak_button := page.find_child("Radio_runway_in_use", true, false) as Button
	if speak_button != null: speak_button.pressed.emit()
	check("the_host_accepts_the_real_radio_button_path", speak_button != null and spoke[0].is_empty(), spoke[0])
	var line := await _wait_line(child_log, "RADIO_CHILD ")
	check("the_client_without_a_model_or_library_plays_the_clip", line.contains("no_model=true")
		and line.contains("samples=") and not line.contains("samples=0"), line)
	check("the_joiner_cannot_publish_a_clip", line.contains("refusal=Only_the_host_sends_radio_clips."), line)
	check("the_host_plays_the_same_decoded_clip_path", Headphones.played_clips == 1
		and Headphones.last_clip_samples > 0, "%d clips, %d samples" % [Headphones.played_clips, Headphones.last_clip_samples])
	var wave := RadioClip.stream(Radio.last_clip)
	var audio_path := ProjectSettings.globalize_path("user://radio_peers_host")
	var saved := wave.save_to_wav(audio_path) if wave != null else ERR_INVALID_DATA
	check("the_transmitted_clip_is_saved_for_a_human_to_hear", saved == OK,
		"%s.wav (%s)" % [audio_path, error_string(saved)])
	_finish()

func _wait_line(path: String, prefix: String) -> String:
	var since := Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < WAIT_MSEC:
		if FileAccess.file_exists(path):
			for line in FileAccess.get_file_as_string(path).split("\n"):
				if line.begins_with(prefix): return line.strip_edges()
		await get_tree().physics_frame
	return "TIMEOUT"

func _finish() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid): OS.kill(child_pid)
	Net.leave("radio peers done")
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
