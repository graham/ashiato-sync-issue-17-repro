extends Node
## Headless, THREE real processes over a real socket: does the flat 2D voice lobby hold a session of people who can see
## each other, be put on teams by the host, and talk in text?
##
##   Godot --headless --path cockpit res://tests/lobby2d_peers.tscn
##
## WHY THREE AND NOT TWO. Two machines cannot tell "everybody agrees" from "the two of them agree", and they cannot test
## the thing teams exist for at all: with two players every team of one is also every player not on another team. BOB is
## here so that a team can have somebody outside it, and so that a player LEAVING can be watched from two machines that
## are still there.
##
## EVERY CHECK IS ON WHAT THE THREE MACHINES SAY ABOUT EACH OTHER, from `FlatLobby`'s own `LOBBY_REPORT` line once a
## second and its `LOBBY_CHAT` line per message. Not on `Net` in this process: this suite exists because a lobby that
## works in one process proved nothing about two, and the roster it draws is published by a host over a socket.
##
## THE ROBOT PRESSES THE BUTTONS (CLAUDE.md rule 3). `--press-team=` presses the host's own TEAM button on a row, and
## `--say=` types into the entry field and presses SEND. Nothing here calls `Net.set_team` or `Net.say_in_chat`: a test
## that did would pass with the buttons wired to nothing.
##
## MUTANTS THIS CATCHES, each run against it:
##   - `Net.set_team` writing the team without publishing the roster: the two joiners never see ALICE on BLUE.
##   - the host mapping peers to players off the pilots again (`Sim.client_of_peer`): nobody but the host is ever listed,
##     because a lobby seats nobody -- this is the bug the suite was written against.
##   - `_take_a_chat_line` numbering a line but not emitting: every machine's `chat` count stays 0.
##   - a peer's chat accepted without `admitted`: not caught here, and `tests/lobby2d.gd` has it.
##
## A PLAYER WHO LEAVES is killed mid-run rather than asked to leave: a process that dies is the case a stale row survives,
## and it is what actually happens to somebody's laptop.
##
## THIS CHECKOUT'S PORTS (`TestPorts`): 48280-48289, which no other suite uses -- the highest claimed before this was
## `jet_arms_peers`/`spotting_peers` at 48240. NOT 48300, which was the first try: the block every suite asks from is
## 47900-48299 inclusive (`TestPorts.of`), so 48300 push_errors, returns 0, and the suite says every one of its ports is
## held and stops in four seconds -- which is exactly what it did.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 48280
const PORTS: int = 10
## Seconds for three processes to boot, join, settle a roster and run their hands, before the children are killed. The
## hands fire on the third report tick, so nothing happens before about 4 s on any of them.
const PATIENCE_SECONDS: float = 75.0
## What ALICE and the host say. Chosen to be ordinary text with a space in it -- the report line puts the message last for
## exactly this reason -- and to be told apart from each other.
const ALICE_SAYS: String = "radio check from alice"
const HOST_SAYS: String = "host hears you"

var _failures: PackedStringArray = []
var _children: Array[int] = []
var _logs: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lobby2d_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	for who in ["host", "alice", "bob"]:
		_logs[who] = ProjectSettings.globalize_path(TestPorts.log_for("lobby2d_peers", who))
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var started: bool = false
	var since: int = 0
	while port != 0 and not started:
		await _bury()
		for path in _logs.values():
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		# THE HOST PUTS ALICE ON A TEAM WITH ITS OWN BUTTON, twice, which is NO TEAM -> RED -> BLUE.
		# WAIT FOR ALL THREE TO BE LISTED, then press ALICE's TEAM button twice -- NO TEAM to RED to BLUE -- and say a
		# line. By name, because sync numbers whichever joiner its packets reach first: this run has BOB as client 2 and
		# ALICE as 3, and an earlier version of this suite named the id and moved the wrong player.
		_spawn(project, "host", ["--host=%d" % port, "--level=voice", "--player-name=HOST", "--report=1",
			"--hands-at=3", "--press-team=ALICE:2", "--say=%s" % HOST_SAYS])
		await get_tree().create_timer(0.4).timeout
		if _read("host").contains("BOOT_ERROR=Could not listen"):
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[lobby2d_peers] port %d is in use; trying %d" % [port, next])
			_kill_the_children()
			port = next
			continue
		_spawn(project, "alice", ["--join=127.0.0.1:%d" % port, "--level=voice", "--player-name=ALICE", "--report=1",
			"--hands-at=3", "--say=%s" % ALICE_SAYS])
		# BOB PRESSES A TEAM BUTTON HE HAS NOT GOT: a client's rows carry a label, never a button, so his hands say
		# `no_row_for` and nobody's team moves. That is the negative this run can make without a fourth process.
		_spawn(project, "bob", ["--join=127.0.0.1:%d" % port, "--level=voice", "--player-name=BOB", "--report=1",
			"--hands-at=3", "--press-team=ALICE:1"])
		since = Time.get_ticks_msec()
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			if _everybody_is_in() and _the_talking_is_done():
				break
			await get_tree().create_timer(0.2).timeout
		started = true

	var reports: Dictionary = {}
	for who in _logs:
		reports[who] = _latest_report(String(who))
	print("[lobby2d_peers] after %d ms: %s" % [Time.get_ticks_msec() - since, reports])

	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))

	# ---- everybody sees everybody, by name -------------------------------------------------------
	var counted: PackedStringArray = []
	var all_three: bool = true
	for who in ["host", "alice", "bob"]:
		var said: Dictionary = reports[who]
		counted.append("%s:%d" % [who, int(said.get("players", 0))])
		if int(said.get("players", 0)) != 3:
			all_three = false
	_check("every_machine_lists_all_three_players", all_three, " ".join(counted))
	var names_everywhere: bool = true
	for who in ["host", "alice", "bob"]:
		var listed: String = String(reports[who].get("who", ""))
		for name in ["HOST", "ALICE", "BOB"]:
			if not listed.contains(name):
				names_everywhere = false
	_check("and_names_them_rather_than_numbering_them", names_everywhere,
		"host listed %s" % String(reports["host"].get("who", "-")))

	# ---- the host's team reaches every machine ---------------------------------------------------
	var team_everywhere: bool = true
	var teams_said: PackedStringArray = []
	for who in ["host", "alice", "bob"]:
		var team: int = _team_of(reports[who], "ALICE")
		teams_said.append("%s saw %d" % [who, team])
		if team != 2:
			team_everywhere = false
	_check("the_team_the_host_assigned_reaches_every_machine", team_everywhere, " ".join(teams_said))
	# AND NOBODY ELSE MOVED. A cycle that wrote every card, or a team kept per machine, shows up here.
	var others_clear: bool = true
	for who in ["host", "alice", "bob"]:
		if _team_of(reports[who], "HOST") != 0 or _team_of(reports[who], "BOB") != 0:
			others_clear = false
	_check("and_left_everybody_else_on_no_team", others_clear,
		"host listed %s" % String(reports["host"].get("who", "-")))
	_check("a_client_is_not_even_offered_a_team_button", _read("bob").contains("LOBBY_HANDS no_row_for=ALICE"),
		"bob's hands said %s" % _hands_said("bob"))

	# ---- text chat both ways --------------------------------------------------------------------
	var alice_heard_by: PackedStringArray = []
	var alice_everywhere: bool = true
	for who in ["host", "alice", "bob"]:
		var got: bool = _chat_lines(String(who)).has(ALICE_SAYS)
		alice_heard_by.append("%s:%s" % [who, "yes" if got else "no"])
		if not got:
			alice_everywhere = false
	_check("a_line_typed_on_a_joiner_reaches_every_machine", alice_everywhere, " ".join(alice_heard_by))
	var host_heard_by: PackedStringArray = []
	var host_everywhere: bool = true
	for who in ["host", "alice", "bob"]:
		var got: bool = _chat_lines(String(who)).has(HOST_SAYS)
		host_heard_by.append("%s:%s" % [who, "yes" if got else "no"])
		if not got:
			host_everywhere = false
	_check("and_a_line_typed_on_the_host_reaches_every_joiner", host_everywhere, " ".join(host_heard_by))
	# THE LINE IS ATTRIBUTED TO WHOEVER TYPED IT, on a machine that is neither of them: the host writes the player
	# number from who the peer IS, so a peer cannot sign somebody else's name to a message.
	var bobs_view: String = _chat_author("bob", ALICE_SAYS)
	_check("and_is_attributed_to_whoever_typed_it", bobs_view == "ALICE",
		"bob credited '%s'" % bobs_view)

	# ---- somebody leaves ------------------------------------------------------------------------
	await _bob_goes_away()
	var after: Dictionary = {}
	for who in ["host", "alice"]:
		after[who] = _latest_report(String(who))
	var gone_everywhere: bool = true
	var after_said: PackedStringArray = []
	for who in ["host", "alice"]:
		var listed: String = String(after[who].get("who", ""))
		after_said.append("%s: %s" % [who, listed])
		if int(after[who].get("players", 0)) != 2 or listed.contains("BOB"):
			gone_everywhere = false
	_check("a_player_who_leaves_is_gone_from_every_list", gone_everywhere, " ".join(after_said))

	_finish()


## ---- the children ------------------------------------------------------------------------------

func _spawn(project: String, who: String, flags: Array) -> void:
	var arguments: Array = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120",
		"--log-file", String(_logs[who]), "--path", project, "--"]
	arguments.append_array(flags)
	_children.append(OS.create_process(OS.get_executable_path(), arguments))


## KILL BOB AND WAIT FOR THE OTHERS TO SAY HE IS GONE. His process is killed rather than asked to leave, because a row
## left behind by a machine that died is the stale row this check is about. The wait is bounded and then reported either
## way -- the check below reads what the logs actually say.
func _bob_goes_away() -> void:
	var bob: int = _children[_children.size() - 1]
	if bob > 0 and OS.is_process_running(bob):
		OS.kill(bob)
	# LONG ENOUGH FOR ENET TO NOTICE A DEAD PEER, which is a property of the socket and not of this game: a killed
	# process sends no goodbye, so the host waits out its own peer timeout before anybody can be removed from a list.
	# Twenty seconds was not always enough on a loaded machine and the check read as "the row is stale" when it meant
	# "nobody has been told yet".
	var until: int = Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < until:
		var host_said: Dictionary = _latest_report("host")
		var alice_said: Dictionary = _latest_report("alice")
		if int(host_said.get("players", 9)) == 2 and int(alice_said.get("players", 9)) == 2:
			break
		await get_tree().create_timer(0.2).timeout


func _everybody_is_in() -> bool:
	for who in ["host", "alice", "bob"]:
		if int(_latest_report(String(who)).get("players", 0)) != 3:
			return false
	return true


func _the_talking_is_done() -> bool:
	for who in ["host", "alice", "bob"]:
		var lines: PackedStringArray = _chat_lines(String(who))
		if not lines.has(ALICE_SAYS) or not lines.has(HOST_SAYS):
			return false
	return true


## ---- what the logs say -------------------------------------------------------------------------

func _read(who: String) -> String:
	var path: String = String(_logs[who])
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## The last `LOBBY_REPORT me=1 host=yes players=3 who=1:HOST:0,2:ALICE:2 chat=2 said=3` in a log, as a Dictionary.
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


## WHAT TEAM THAT MACHINE SAW A NAMED PLAYER ON, off the report's `who=1:HOST:0,2:ALICE:2` field, or -1 if it did not
## list them at all. By name rather than by client id because the id is the thing under test in the check above.
func _team_of(report: Dictionary, name: String) -> int:
	for entry in String(report.get("who", "")).split(",", false):
		var parts: PackedStringArray = entry.split(":")
		if parts.size() == 3 and String(parts[1]) == name:
			return String(parts[2]).to_int()
	return -1


## Every message that machine DREW, in order. `text=` is last on the line, so the message is everything after it.
func _chat_lines(who: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for line in _read(who).split("\n"):
		if line.begins_with("LOBBY_CHAT ") and line.contains(" text="):
			out.append(line.substr(line.find(" text=") + 6).strip_edges())
	return out


## WHO THAT MACHINE ENDED UP SAYING HAD TYPED A MESSAGE. Two lines are read together: `LOBBY_CHAT` gives the message its
## line number, and `LOBBY_NAMED` says who that line was drawn as -- reported again whenever the board corrects itself, so
## the LAST one is what the player is looking at. A name may contain a space ("PLAYER 3"), which is why it has a line of
## its own with the name last on it.
func _chat_author(who: String, message: String) -> String:
	var numbered: int = -1
	for line in _read(who).split("\n"):
		if not line.begins_with("LOBBY_CHAT ") or not line.contains(" text="):
			continue
		if line.substr(line.find(" text=") + 6).strip_edges() != message:
			continue
		for pair in line.split(" ", false):
			if pair.begins_with("n="):
				numbered = String(pair.substr(2)).to_int()
	if numbered < 0:
		return ""
	var name: String = ""
	for line in _read(who).split("\n"):
		if line.begins_with("LOBBY_NAMED n=%d " % numbered) and line.contains(" name="):
			name = line.substr(line.find(" name=") + 6).strip_edges()
	return name


func _hands_said(who: String) -> String:
	var out: PackedStringArray = []
	for line in _read(who).split("\n"):
		if line.begins_with("LOBBY_HANDS "):
			out.append(line.strip_edges())
	return "nothing" if out.is_empty() else " | ".join(out)


func _kill_the_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


## Let a killed child's socket go before the next attempt takes the same port.
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
