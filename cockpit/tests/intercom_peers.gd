extends Node
## Headless, THREE real processes over a real socket: does a held button put somebody's voice on the other machines,
## does the lamp tell the truth, and — the one that decides the feature — **does team talk reach the team and NOBODY
## else?**
##
##   Godot --headless --path cockpit res://tests/intercom_peers.tscn
##
## THE NEGATIVE IS THE POINT. A run where everyone hears everything proves nothing about teams: the check that matters
## asserts on samples ABSENT, by count, at the machine that must not have them. So HOST and ALICE are put on the same
## team and BOB is left on none, ALICE holds the team button, and BOB must end the run having played **zero** frames
## while still seeing ALICE's lamp lit — because the user asked for an indicator that is always visible, and the lamp
## is the host's word rather than "am I receiving audio from them".
##
## AND SILENCE MUST FAIL. Every positive check is on frames and samples actually played at the far machine, never on
## "no error was thrown": a voice test that passes in a silent session is worthless. The tone is a 440 Hz sine fed in
## at the capture seam (`Microphone.feed`) because whether a microphone on this desk hears anything is a property of
## the desk — `tests/voice_probe.gd` found every device on this one reading silence. Everything downstream of that seam
## is the shipping path: the same frames, encoder, envelope, host routing and playback.
##
## AND BOTH KINDS IN ONE SESSION. The host also asks the tower to speak to its own team, so the run proves a client
## receives a live frame AND a generated line and can tell them apart -- the user's channel requirement reduced to the
## one thing that demonstrates it -- and that the generated line obeys the same teams the live voice does. The tower's
## tone goes in through `Radio.publish_pcm`, which is the function `Headphones.rendered` calls with Kokoro's own
## samples, so the encode, carry, validate and play path is identical; the synthesis itself is `radio_peers`'.
##
## THE ROBOT HOLDS THE REAL BUTTON. `--talk=all` and `--talk=team` go through `Intercom.start_talking`, which is what
## the on-screen button and the T and G keys call.
##
## MUTANTS THIS CATCHES, each run against it:
##   - the team filter removed from `Net._route_a_voice_frame`: BOB hears ALICE's team talk and the negative fails;
##   - the lamp read from local frames instead of `Net.is_talking`: BOB's lamp for ALICE stays dark, and the host lights
##     every row rather than one. (This mutant PASSED until the lamp checks were changed to read the painted colour
##     rather than `Net.talking` -- see `_lamps_lit`.)
##
## AND ONE THIS SUITE DOES NOT CATCH, said plainly rather than claimed: making `_hear_a_voice_frame` trust the frame's
## own `speaker` field instead of stamping it from the peer changes NOTHING here, because every client in this run is
## honest and writes its own id. Catching it needs a peer that lies about who it is, which this harness has no way to
## be. `tests/intercom.gd` holds what can be checked without one -- that `stamp_the_speaker` overwrites whatever it is
## given -- and the real defence is that the host never reads that field at all.
##
## THIS CHECKOUT'S PORTS (`TestPorts`): 48260-48269, below `lobby2d_peers`' 48280 and above `jet_arms_peers`' 48240.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 48260
const PORTS: int = 10
const PATIENCE_SECONDS: float = 90.0

var _failures: PackedStringArray = []
var _children: Array[int] = []
var _logs: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[intercom_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	for who in ["host", "alice", "bob"]:
		_logs[who] = ProjectSettings.globalize_path(TestPorts.log_for("intercom_peers", who))
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var started: bool = false
	while port != 0 and not started:
		await _bury()
		for path in _logs.values():
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		# THE HOST PUTS ITSELF AND ALICE ON RED, and leaves BOB on no team. One press each: NO TEAM -> RED.
		# AND THE TOWER SPEAKS TO THE HOST'S OWN TEAM, which is ALICE's. The same audience rule as the live voice, so BOB
		# must hear neither kind.
		_spawn(project, "host", ["--host=%d" % port, "--level=voice", "--player-name=HOST", "--report=1",
			"--hands-at=3", "--press-team=HOST:1", "--press-team=ALICE:1", "--tower=team"])
		await get_tree().create_timer(0.4).timeout
		if _read("host").contains("BOOT_ERROR=Could not listen"):
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[intercom_peers] port %d is in use; trying %d" % [port, next])
			_kill_the_children()
			port = next
			continue
		# ALICE TALKS TO HER TEAM, which is HOST and herself. BOB is on no team and must hear none of it.
		_spawn(project, "alice", ["--join=127.0.0.1:%d" % port, "--level=voice", "--player-name=ALICE", "--report=1",
			"--hands-at=3", "--talk=team:600"])
		_spawn(project, "bob", ["--join=127.0.0.1:%d" % port, "--level=voice", "--player-name=BOB", "--report=1",
			"--hands-at=3"])
		var since: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			if _the_talking_is_done():
				break
			await get_tree().create_timer(0.2).timeout
		# WAIT FOR THE LAMP TO GO OUT, BY READING THAT IT DID -- never by sleeping for a while.
		#
		# THIS WAS A FIXED `create_timer(2.0)` AND IT FAILED THREE RUNS OUT OF THREE UNDER THE RUNNER WHILE PASSING BY
		# HAND. A `SceneTreeTimer` counts the tree's own process time, and the runner starts every suite with
		# `--fixed-fps 120`, so two of the suite's "seconds" go by in a fraction of two real ones -- while the children
		# are separate processes living in real time. The suite was reading the host's last report before the host had
		# made a new one, and calling a lamp that had not been given time to clear a lamp that would not clear.
		#
		# `Time.get_ticks_msec` is the wall clock and the log is the evidence, so this waits for the thing itself.
		var clear_by: int = Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < clear_by:
			if String(_latest_report("host").get("talking", "+")) == "-":
				break
			await get_tree().create_timer(0.2).timeout
		started = true

	var reports: Dictionary = {}
	for who in ["host", "alice", "bob"]:
		reports[who] = _latest_report(String(who))
	print("[intercom_peers] %s" % reports)

	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))
	_check("the_host_and_alice_are_on_a_team_and_bob_is_not",
		_team_of(reports["host"], "ALICE") == 1 and _team_of(reports["host"], "HOST") == 1
			and _team_of(reports["host"], "BOB") == 0,
		"host listed %s" % String(reports["host"].get("who", "-")))

	# ---- the positive: the team hears it, in samples ---------------------------------------------
	var host_live: int = int(reports["host"].get("live", 0))
	_check("a_team_mate_hears_the_voice", host_live > 0,
		"the host played %d live frames, %s samples" % [host_live, reports["host"].get("samples", "?")])
	# `samples >= frames * 100` IS TRUE OF ZERO AND ZERO, which is the shape of check this whole suite exists to avoid:
	# it passed on the first run, where nothing arrived at all. The sample count must be positive in its own right.
	var host_samples: int = int(reports["host"].get("samples", 0))
	_check("and_it_is_real_audio_and_not_an_empty_frame",
		host_samples > 0 and host_live > 0 and host_samples >= host_live * 100,
		"%d samples over %d frames" % [host_samples, host_live])
	# ALICE'S OWN MACHINE KNOWS WHAT ALICE IS, and knows it from the moment sync numbers her. Asking the HOST's roster
	# for "the player called ALICE" is the third place in this lane where a name was used as a key and the card had not
	# arrived yet: under load the host's last report still read `PLAYER 3` and the lookup returned -1, failing two checks
	# that had nothing to do with names. `me=` is that machine's own client id and is never late.
	var alice_is: int = int(reports["alice"].get("me", -1))
	_check("and_the_voice_is_attributed_to_whoever_spoke", _speakers_heard_by("host").has(alice_is),
		"the host credited clients %s and ALICE is %d; by name it said %s"
			% [_speakers_heard_by("host"), alice_is, _voices_heard_by("host")])
	# ALICE'S OWN AUDIO IS LABELLED LIVE, which is a sharper claim than "some kind 0 arrived" -- and it has to be, now
	# that the host hears a GENERATED line in the same run. An earlier version asserted the host heard kind 0 "and not
	# kind 1", which was only ever true because nothing generated had been sent yet; step 4 made it false and the check
	# caught itself.
	_check("and_it_is_labelled_as_a_live_microphone_and_not_a_generated_line",
		_kinds_from("host", alice_is) == [0],
		"the host labelled client %d's audio %s, and heard kinds %s in all"
			% [alice_is, _kinds_from("host", alice_is), _kinds_heard_by("host")])

	# ---- THE NEGATIVE: the other team hears NOTHING ----------------------------------------------
	_check("a_player_on_another_team_hears_not_one_sample",
		int(reports["bob"].get("live", 0)) == 0 and int(reports["bob"].get("samples", 0)) == 0,
		"bob played %s frames and %s samples" % [reports["bob"].get("live", "?"), reports["bob"].get("samples", "?")])
	_check("and_no_voice_reached_bob_at_all", _speakers_heard_by("bob").is_empty(),
		"bob heard clients %s" % ["nothing" if _speakers_heard_by("bob").is_empty() else _speakers_heard_by("bob")])

	# ---- THE TWO KINDS IN ONE SESSION, TOLD APART ------------------------------------------------
	# The user's channel ask, reduced to the one thing that proves it: a client receives a live frame and a generated
	# line in the same session and can say which was which.
	var alice_live: int = int(reports["alice"].get("live", 0))
	var alice_generated: int = int(reports["alice"].get("generated", 0))
	_check("a_listener_receives_a_generated_line_as_well_as_live_voice",
		alice_generated > 0, "alice played %d generated" % alice_generated)
	_check("and_tells_the_two_kinds_apart",
		alice_generated > 0 and _kinds_heard_by("alice").has(1),
		"alice heard kinds %s (0 is live, 1 is generated); she played %d live and %d generated"
			% [_kinds_heard_by("alice"), alice_live, alice_generated])
	# AND THE GENERATED LINE OBEYS THE SAME TEAMS. A spoken order reaching a team it was not meant for is the same fault
	# as a voice doing it, and the host is subject to its own filter.
	_check("and_a_generated_line_sent_to_a_team_reaches_nobody_outside_it",
		int(reports["bob"].get("generated", 0)) == 0,
		"bob played %s generated" % reports["bob"].get("generated", "?"))

	# ---- the lamp is the host's word, and reaches the machine the audio did not -------------------
	# WHOSE lamp, not merely "a lamp": a machine that lights every row whenever anything is happening is as wrong as one
	# that lights none, and only naming the client catches it.
	var alice_client: int = _client_called(reports["host"], "ALICE")
	_check("the_speakers_lamp_lit_on_their_own_machine", _lit_only("alice", alice_client),
		"alice painted %s, ALICE is %d (%s)" % [_lamps_lit("alice"), alice_client, _lamps_seen("alice")])
	_check("and_on_their_team_mates_machine", _lit_only("host", alice_client),
		"the host painted %s (%s)" % [_lamps_lit("host"), _lamps_seen("host")])
	_check("AND_ON_THE_MACHINE_THAT_HEARD_NONE_OF_IT", _lit_only("bob", alice_client),
		"bob painted %s (%s)" % [_lamps_lit("bob"), _lamps_seen("bob")])
	# AND IT GOES OUT AGAIN. A lamp that never clears is as much a lie as one that never lights, and it is the failure
	# a decay-by-timeout is most likely to have.
	var quiet_at_the_end: bool = String(reports["host"].get("talking", "-")) == "-"
	_check("and_the_lamp_goes_out_when_the_button_is_let_go", quiet_at_the_end,
		"the host's last report said talking=%s" % reports["host"].get("talking", "?"))

	_finish()


## ---- the children ------------------------------------------------------------------------------

func _spawn(project: String, who: String, flags: Array) -> void:
	var arguments: Array = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120",
		"--log-file", String(_logs[who]), "--path", project, "--"]
	arguments.append_array(flags)
	_children.append(OS.create_process(OS.get_executable_path(), arguments))


func _the_talking_is_done() -> bool:
	return _read("alice").contains("LOBBY_HANDS talked_frames=") \
		and int(_latest_report("host").get("live", 0)) > 0 \
		and int(_latest_report("alice").get("generated", 0)) > 0


## ---- what the logs say -------------------------------------------------------------------------

func _read(who: String) -> String:
	var path: String = String(_logs[who])
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _latest_report(who: String) -> Dictionary:
	var out: Dictionary = {}
	for line in _read(who).split("\n"):
		if not line.begins_with("LOBBY_REPORT "):
			continue
		out.clear()
		for pair in line.substr(13).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out


## Which client id a named player has, off a report's `who=1:HOST:1,...` field.
func _client_called(report: Dictionary, name: String) -> int:
	for entry in String(report.get("who", "")).split(",", false):
		var parts: PackedStringArray = entry.split(":")
		if parts.size() == 3 and String(parts[1]) == name:
			return String(parts[0]).to_int()
	return -1


func _team_of(report: Dictionary, name: String) -> int:
	for entry in String(report.get("who", "")).split(",", false):
		var parts: PackedStringArray = entry.split(":")
		if parts.size() == 3 and String(parts[1]) == name:
			return String(parts[2]).to_int()
	return -1


## WHOSE VOICES THAT MACHINE PLAYED, by name. `from=` is last on the line because a name may contain a space.
func _voices_heard_by(who: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for line in _read(who).split("\n"):
		if line.begins_with("LOBBY_VOICE ") and line.contains(" from="):
			var name: String = line.substr(line.find(" from=") + 6).strip_edges()
			if not out.has(name):
				out.append(name)
	return out


## WHICH KINDS THAT MACHINE PLAYED FROM A GIVEN SPEAKER, matched on the CLIENT ID and never on the name.
##
## TWO BUGS LIVED IN THE NAME VERSION OF THIS, and the first is a GDScript trap worth remembering.
##
## Its parameter was called `name`, and **`name` is a property of `Node`**. The comparison read the SCENE NODE'S name --
## "IntercomPeers" -- so it matched nothing and the function returned an empty array every time. Its sibling
## `_voices_heard_by` does the same parse and works, because it assigns to a local first. The check failed 3 runs of 3
## while the host's log plainly said `speaker=2 kind=0 from=ALICE`.
##
## And it was load-sensitive even once that was fixed: `LOBBY_VOICE` writes whatever `Net.name_of` answers when the
## frame is played, and under load a speaker's roster card can arrive AFTER their first frames, so the line reads
## `from=PLAYER 3`. The id is on the same line, is what the host stamped, and does not depend on when a card turned up.
## The name stays on the line for a person reading the log.
##
## AND A THIRD, WHICH WAS NOT ABOUT NAMES AT ALL. Both of these helpers were once written with a REAL newline
## inside the split literal. On Windows that literal is "\r\n" -- this file is checked out CRLF -- while the log
## Godot writes is LF-only, so the split matched nothing, handed back the whole file as a single line, and both
## helpers returned empty again while `_voices_heard_by`, written `split("\n")`, read the very same string
## correctly. It held up a night of merges. Write `"\n"`. See working_with_godot.md, "A string literal broken by
## a real newline carries the FILE's line ending".
func _kinds_from(who: String, client: int) -> Array:
	var out: Array = []
	for line in _read(who).split("\n"):
		if not line.begins_with("LOBBY_VOICE "):
			continue
		var spoke: int = -1
		var kind: int = -1
		for pair in line.split(" ", false):
			if pair.begins_with("speaker="):
				spoke = String(pair.substr(8)).to_int()
			elif pair.begins_with("kind="):
				kind = String(pair.substr(5)).to_int()
		if spoke == client and kind >= 0 and not out.has(kind):
			out.append(kind)
	out.sort()
	return out


## WHOSE VOICES THAT MACHINE PLAYED, as client ids rather than names. Same two reasons.
func _speakers_heard_by(who: String) -> Array:
	var out: Array = []
	for line in _read(who).split("\n"):
		if not line.begins_with("LOBBY_VOICE "):
			continue
		for pair in line.split(" ", false):
			if pair.begins_with("speaker="):
				var spoke: int = String(pair.substr(8)).to_int()
				if not out.has(spoke):
					out.append(spoke)
	out.sort()
	return out


func _kinds_heard_by(who: String) -> Array:
	var out: Array = []
	for line in _read(who).split("\n"):
		if not line.begins_with("LOBBY_VOICE "):
			continue
		for pair in line.split(" ", false):
			if pair.begins_with("kind="):
				var kind: int = String(pair.substr(5)).to_int()
				if not out.has(kind):
					out.append(kind)
	return out


## WHICH LAMPS THAT MACHINE ACTUALLY PAINTED, at the moment most were lit: the client ids read back off the rows'
## `ColorRect`s, not off `Net.talking`.
##
## THIS READ `Net.talking` AND THE SUITE WAS A TAUTOLOGY. A mutant that painted every lamp from "have I played any
## frames myself" -- a local guess, which is precisely what the lamp must not be -- passed all twelve checks, because
## what was being read was the fact the lamp is painted FROM rather than the paint. Reading the drawn colour is the
## difference between testing the feature and testing the variable behind it.
func _lamps_lit(who: String) -> PackedStringArray:
	var best: PackedStringArray = []
	for line in _read(who).split("\n"):
		if not line.begins_with("LOBBY_LAMPS lit="):
			continue
		var field: String = line.substr(16).split(" ")[0].strip_edges()
		if field == "-":
			continue
		var these: PackedStringArray = field.split("+", false)
		if these.size() > best.size():
			best = these
	return best


## Did that machine ever paint exactly one lamp, and was it that player's?
func _lit_only(who: String, client: int) -> bool:
	var lit: PackedStringArray = _lamps_lit(who)
	return lit.size() == 1 and String(lit[0]) == str(client)


func _lamps_seen(who: String) -> String:
	var out: PackedStringArray = []
	for line in _read(who).split("\n"):
		if line.begins_with("LOBBY_LAMPS "):
			out.append(line.strip_edges())
	return "nothing" if out.is_empty() else " | ".join(out.slice(maxi(0, out.size() - 3)))


func _kill_the_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


func _bury() -> void:
	_kill_the_children()
	await get_tree().create_timer(0.3).timeout


func _finish() -> void:
	_kill_the_children()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
