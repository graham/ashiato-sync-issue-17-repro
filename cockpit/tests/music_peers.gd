extends Node
## Real ENet host and two sequential joiners: current music, fade and late-join state cross the carrier.

const FIRST_PORT := 47970
const PORTS := 6
const WAIT_MSEC := 30000
var failures: Array[String] = []
var children: Array[int] = []

func check(label: String, ok: bool, detail: String) -> void:
	print("[music_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
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
	if args().has("--music-child"):
		_run_child()
	else:
		_run_parent()

func _run_child() -> void:
	Net.session_ready.connect(func(): Net.level_loaded(""))
	Net.join("127.0.0.1", int(value("--join=", str(TestPorts.of(FIRST_PORT)))))
	var since := Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < WAIT_MSEC:
		if not String(Net.music_state.get("track", "")).is_empty():
			var refusal := Net.choose_music("client_choice", -3.0, 0.0)
			print("MUSIC_CHILD track=%s from=%.1f to=%.1f fade=%.1f n=%d refusal=%s" % [Net.music_state["track"],
				Net.music_state["volume_from"], Net.music_state["volume_to"], Net.music_state["fade_frames"],
				Net.music_state["music_n"], refusal.replace(" ", "_")])
			get_tree().quit()
			return
		await get_tree().physics_frame
	print("MUSIC_CHILD TIMEOUT")
	get_tree().quit(1)

func _run_parent() -> void:
	# THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently: hunting by calling `Net.host` until one
	# worked printed "ERROR: Couldn't create an ENet host." for every held port, and the runner's error gate fails that.
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	if port != 0:
		Net.host(port)
	check("the_host_opens_a_real_enet_session", Net.is_in_session,
		"port %d" % port if port != 0 else TestPorts.busy(FIRST_PORT, PORTS))
	if not Net.is_in_session:
		_finish(); return
	Net.level_loaded("")
	var first_log := log_path("first")
	children.append(spawn_child(port, first_log))
	var since := Time.get_ticks_msec()
	while Net.admitted.is_empty() and Time.get_ticks_msec() - since < WAIT_MSEC:
		await get_tree().physics_frame
	check("the_first_joiner_is_admitted", not Net.admitted.is_empty(), str(Net.admitted.keys()))
	check("the_host_starts_a_track", Net.choose_music("test_tone", -12.0, 0.0).is_empty(), str(Net.music_state))
	var first := await wait_line(first_log)
	check("a_joiner_receives_the_hosts_track", first.contains("track=test_tone") and first.contains("to=-12.0"), first)
	check("and_its_own_play_request_is_refused", first.contains("refusal=Only_the_host_chooses_the_music."), first)
	# Let the host's pure frame fade begin before the late joiner asks for the session state.
	check("the_host_announces_one_fade_not_a_volume_stream", Net.fade_music(-30.0, 5.0).is_empty()
		and int(Net.music_state["fade_frames"]) == int(5.0 * Sim.tick_hz), str(Net.music_state))
	var late_log := log_path("late")
	children.append(spawn_child(port, late_log))
	var late := await wait_line(late_log)
	check("a_late_joiner_receives_the_current_track_and_fade_in_its_level_hello", late.contains("track=test_tone")
		and late.contains("to=-30.0") and late.contains("fade=600.0"), late)
	_finish()

func spawn_child(port: int, log: String) -> int:
	return OS.create_process(OS.get_executable_path(), PackedStringArray(["--headless", "--xr-mode", "off", "--desktop-only",
		"--fixed-fps", "120", "--log-file", log, "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/music_peers.tscn", "--", "--music-child", "--join=%d" % port]))

func log_path(who: String) -> String:
	var path := ProjectSettings.globalize_path(TestPorts.log_for("music_peers", who))
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	return path

func wait_line(path: String) -> String:
	var since := Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < WAIT_MSEC:
		if FileAccess.file_exists(path):
			for line in FileAccess.get_file_as_string(path).split("\n"):
				if line.begins_with("MUSIC_CHILD "): return line.strip_edges()
		await get_tree().physics_frame
	return "TIMEOUT"

func _finish() -> void:
	for pid in children:
		if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
	Net.leave("music peers done")
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
