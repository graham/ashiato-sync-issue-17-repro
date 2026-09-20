extends Node
## Headless, three processes over real ENet: A SESSION THAT IS FULL SAYS SO, in words, to the player it turns away.
##
##   Godot --headless --path cockpit res://tests/players_peers.tscn
##
## ASKED FOR ON 2026-09-18, with the player cap raised from eight to sixty-four: "a join at player 9 and at 64 works; a
## 65th is refused out loud." Sixty-five processes is not a suite, so the host here takes the door every host has
## (`--players=N`, `Net.choose_session_size`) and chooses a session of TWO: itself and one joiner. A second joiner is
## the sixty-fifth of this session. `tests/players.gd` fills a session of sixty-four in one process, where the
## simulation is the thing being measured and the socket is not.
##
## BEFORE: the carrier was opened for exactly the players the session took, and ENet turned the next one away with
## nothing said -- the joiner waited out its deadline and told its player that nothing was listening. Now the carrier
## keeps one place spare, and the host tells whoever takes it "The session is full: 2 players." and lets them go.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47990
const PORTS: int = 8
const PATIENCE_MSEC: int = 70000
## THE REFUSAL'S OWN WORDS, from `Net.refusal_words`, which since the handshake (2026-09-18) go on to name both builds.
const FULL: String = "Can't join: the session is full (2 of 2 players)."
var children: Array[int] = []
var failures: PackedStringArray = []


func check(label: String, ok: bool, detail: String) -> void:
	print("[players_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	# THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently before the host starts; 0 once none is.
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var logs := PackedStringArray()
	while port != 0:
		await bury()
		logs = PackedStringArray([
			ProjectSettings.globalize_path(TestPorts.log_for("players_peers", "host")),
			ProjectSettings.globalize_path(TestPorts.log_for("players_peers", "first")),
			ProjectSettings.globalize_path(TestPorts.log_for("players_peers", "second"))])
		for path in logs:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		children.append(spawn(project, logs[0], ["--host=%d" % port, "--world=lobby", "--report=1", "--players=2"]))
		await get_tree().create_timer(0.3).timeout
		if read(logs[0]).contains("BOOT_ERROR=Could not listen"):
			port = TestPorts.first_free(FIRST_PORT, PORTS, port)
			continue
		children.append(spawn(project, logs[1], ["--join=127.0.0.1:%d" % port, "--report=1"]))
		var first_in: bool = await wait_for(logs[0], "NET_ADMITTED")
		check("the_first_joiner_is_admitted_to_a_session_of_two", first_in, last_lines(logs[0]))
		children.append(spawn(project, logs[2], ["--join=127.0.0.1:%d" % port, "--report=1"]))
		var told: bool = await wait_for(logs[2], FULL)
		check("the_second_joiner_is_told_the_session_is_full_in_words", told, last_lines(logs[2]))
		check("and_the_host_says_why_it_turned_them_away", read(logs[0]).contains("NET_REFUSED side=host code=full"),
			last_lines(logs[0]))
		check("and_the_host_admitted_nobody_but_the_first", read(logs[0]).count("NET_ADMITTED") == 1,
			"%d admissions" % read(logs[0]).count("NET_ADMITTED"))
		break
	await bury()
	check("a_port_was_available", port != 0, "port %d" % port if port != 0 else TestPorts.busy(FIRST_PORT, PORTS))
	# AND A SIZE THAT IS NOT ONE IS REFUSED BEFORE ANYTHING IS HOSTED.
	check("a_session_of_one_is_refused", Net.choose_session_size(1) != "", Net.choose_session_size(1))
	check("so_is_one_past_the_cap", Net.choose_session_size(Net.MAX_PLAYERS + 1) != "",
		Net.choose_session_size(Net.MAX_PLAYERS + 1))
	Net.session_players = Net.MAX_PLAYERS
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func spawn(project: String, log_path: String, user_args: Array[String]) -> int:
	var args: Array[String] = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file", log_path,
		"--path", project, "--"]
	args.append_array(user_args)
	return OS.create_process(OS.get_executable_path(), args)


func read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func last_lines(path: String) -> String:
	var lines: PackedStringArray = read(path).strip_edges().split("\n")
	return " | ".join(lines.slice(maxi(0, lines.size() - 4)))


func wait_for(path: String, words: String) -> bool:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < PATIENCE_MSEC:
		if read(path).contains(words):
			return true
		await get_tree().create_timer(0.25).timeout
	return false


func bury() -> void:
	for pid in children:
		if OS.is_process_running(pid):
			OS.kill(pid)
	children.clear()
	await get_tree().create_timer(0.3).timeout
