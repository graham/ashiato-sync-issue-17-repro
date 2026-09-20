extends Node
## Headless, over real ENet: A JOINER SAYS WHICH BUILD IT IS FIRST, AND ONE THAT IS NOT THE HOST'S IS TURNED AWAY IN WORDS
## THAT NAME BOTH BUILDS -- on the host's log and on the joiner's screen.
##
##   Godot --headless --path cockpit res://tests/handshake_peers.tscn
##
## ASKED FOR ON 2026-09-18: "we need to reject connections from clients that are not running the same version ... It
## should INCLUDE the version number of the server and client in the message. It's REALLY important that a client (and
## the server) know why they can't play together." See Net's "THE HANDSHAKE".
##
## One checkout is one build, so the other builds are PRETENDED: `--pretend-build=<commit>|<line>` and
## `--pretend-protocol=N` make a joiner say it is something else, and everything after that -- the hi on the wire, the
## host's check, the refusal, the joiner's screen -- is the real path. The host and five joiners are processes booted
## with the flags a player would use (`--host=`, `--join=`); the joiner that never says hi and the join that nobody
## answers are this process, through `Net` itself, because a build that predates the hi cannot be booted from this one.
##
## Mutants, each red on the check named: the version check skipped (a pretended build is admitted:
## `the_other_build_is_not_let_in`); the peer closed before its refusal is said (the joiner learns nothing:
## `and_the_joiner_is_told_why_with_both_builds`); the words missing the joiner's build (the same check).
##
## AND WHO NEEDS TO UPDATE (protocol 37, lane/buildtime, 2026-09-19): every build says when it was built, and
## `--pretend-built=<epoch>` moves one side's time. The words each side is shown are read off its own log:
##   an OLDER build, three days behind, is told "Yours is 3 days older than the host's: update yours."
##   a NEWER one, five hours ahead, is told "Yours is 5 hours newer than the host's: the host needs to update."
##   a build from BEFORE the time was said (protocol 36, `--pretend-built=none`) is refused on its protocol, cleanly --
##     not as a hello nobody could read -- and told it is the older build
##   the same commit built two days later is LET IN, and told so on its way in; the host's LOG row says it too
## Mutants: the two times swapped in `update_words` (`the_older_build_is_told_to_update_by_how_much` and its twin go
## red); `built` required in `_read_hi` (the protocol-36 joiner is refused as `bad_hello`:
## `a_build_from_before_the_time_is_refused_on_its_protocol_as_older`); the age left out of the joiner's "Connected"
## line (`the_same_commit_built_later_is_let_in_and_told_how_far_apart`).
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47996
const PORTS: int = 8
const PATIENCE_MSEC: int = 70000
## A BUILD THAT IS NOT THIS ONE: a release a version behind, with a commit this checkout does not have.
const OTHER_COMMIT: String = "1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d"
const OTHER_LINE: String = "0.2.0 soaring-otter · 1a2b3c4d"
## A BUILD AHEAD OF THIS ONE: another commit, a version on.
const NEWER_COMMIT: String = "9f8e7d6c5b4a39281706f5e4d3c2b1a098765432"
const NEWER_LINE: String = "0.2.2 hungry-heron · 9f8e7d6c"
## How far the pretended builds' times are moved from this one's, seconds: each a little past the whole unit the words
## round down to, so "3 days", "5 hours" and "2 days" are the only right answers.
const OLDER_BY: int = 3 * 86400 + 600
const NEWER_BY: int = 5 * 3600 + 60
const LATER_BY: int = 2 * 86400 + 60
var children: Array[int] = []
var failures: PackedStringArray = []


func check(label: String, ok: bool, detail: String) -> void:
	print("[handshake_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var mine: Dictionary = Net.identity()
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var roles: Array[String] = ["host", "same", "other", "protocol", "garbled", "oversized", "newer", "later"]
	var built: int = int(mine["built"])
	var logs: Dictionary = {}
	while port != 0:
		await bury()
		for role in roles:
			logs[role] = ProjectSettings.globalize_path(TestPorts.log_for("handshake_peers", role))
			if FileAccess.file_exists(logs[role]): DirAccess.remove_absolute(logs[role])
		children.append(spawn(project, logs["host"], ["--host=%d" % port, "--world=lobby", "--report=1"]))
		await get_tree().create_timer(0.3).timeout
		if read(logs["host"]).contains("BOOT_ERROR=Could not listen"):
			port = TestPorts.first_free(FIRST_PORT, PORTS, port)
			continue
		var join: String = "--join=127.0.0.1:%d" % port
		children.append(spawn(project, logs["same"], [join, "--report=1"]))
		# THREE DAYS AND TEN MINUTES OLDER, on another commit: "3 days", since the words round down.
		children.append(spawn(project, logs["other"], [join, "--report=1",
			"--pretend-build=%s|%s" % [OTHER_COMMIT, OTHER_LINE], "--pretend-built=%d" % (built - OLDER_BY)]))
		# A BUILD FROM BEFORE PROTOCOL 37: one protocol behind, and a hi with no time in it.
		children.append(spawn(project, logs["protocol"], [join, "--report=1",
			"--pretend-protocol=%d" % (Net.PROTOCOL - 1), "--pretend-built=none"]))
		children.append(spawn(project, logs["newer"], [join, "--report=1",
			"--pretend-build=%s|%s" % [NEWER_COMMIT, NEWER_LINE], "--pretend-built=%d" % (built + NEWER_BY)]))
		# THIS COMMIT, BUILT TWO DAYS LATER: a dev run beside an export of the same code. Let in.
		children.append(spawn(project, logs["later"], [join, "--report=1", "--pretend-built=%d" % (built + LATER_BY)]))
		# A HI THE HOST CANNOT READ: a commit no build could have, and a line that makes the hello too long to carry.
		children.append(spawn(project, logs["garbled"], [join, "--report=1", "--pretend-build=not-a-commit|garbled"]))
		children.append(spawn(project, logs["oversized"], [join, "--report=1",
			"--pretend-build=%s|%s" % [mine["commit"], "x".repeat(600)]]))

		# ---- the same build ----
		var in_ok: bool = await wait_for(logs["host"], "NET_JOINED")
		check("the_same_build_is_let_in", in_ok, last_lines(logs["host"]))
		check("this_build_knows_when_it_was_built", built > 0, "BuildPlate.time() %d" % built)

		# ---- another build ----
		var told: bool = await wait_for(logs["other"], "BOOT_ERROR=")
		var host_log: String = read(logs["host"])
		# THE OTHER BUILD'S ROW BY ITS LINE: the newer build is refused `wrong_version` too, and either may come first.
		var refused_line: String = line_with(host_log, "code=wrong_version", OTHER_LINE)
		check("the_other_build_is_not_let_in", told and host_log.count("NET_JOINED") <= 2
			and _joined_lines(host_log).all(func(row: String) -> bool: return not row.contains(OTHER_LINE)),
			"%d joined; %s" % [host_log.count("NET_JOINED"), last_lines(logs["other"])])
		check("and_the_host_log_says_why_with_both_builds", refused_line.begins_with("NET_REFUSED side=host")
			and refused_line.contains("host=\"%s\"" % mine["line"]) and refused_line.contains("client=\"%s\"" % OTHER_LINE),
			refused_line)
		var words: String = line_with(read(logs["other"]), "BOOT_ERROR=")
		check("and_the_joiner_is_told_why_with_both_builds", words.contains("Can't join") and words.contains(mine["line"])
			and words.contains(OTHER_LINE), words)
		check("and_the_joiner_writes_it_in_its_own_log",
			line_with(read(logs["other"]), "NET_REFUSED side=client code=wrong_version").contains(OTHER_LINE),
			line_with(read(logs["other"]), "NET_REFUSED"))
		check("the_older_build_is_told_to_update_by_how_much",
			words.contains("Yours is 3 days older than the host's: update yours.")
			and refused_line.contains("Yours is 3 days older than the host's: update yours."), words)

		# ---- a newer build ----
		await wait_for(logs["newer"], "BOOT_ERROR=")
		var newer_words: String = line_with(read(logs["newer"]), "BOOT_ERROR=")
		check("the_newer_build_is_told_the_host_is_behind_and_by_how_much",
			newer_words.contains("Yours is 5 hours newer than the host's: the host needs to update.")
			and newer_words.contains(NEWER_LINE) and newer_words.contains(mine["line"]), newer_words)

		# ---- the same commit, built later ----
		await wait_for(logs["later"], "SESSION_SAID=")
		var later_said: String = line_with(read(logs["later"]), "SESSION_SAID=")
		var greeted: String = ""
		for row in read(logs["host"]).split("\n"):
			if row.begins_with("NET_GREETED") and row.contains("2 days newer"):
				greeted = row.strip_edges()
		check("the_same_commit_built_later_is_let_in_and_told_how_far_apart",
			later_said.contains("Connected.") and later_said.contains("Your build is 2 days newer than the host's."),
			later_said if later_said != "" else last_lines(logs["later"]))
		check("and_the_hosts_log_row_says_it_too", greeted.contains("theirs is 2 days newer than this one"),
			greeted if greeted != "" else line_with(read(logs["host"]), "NET_GREETED"))

		# ---- another protocol ----
		await wait_for(logs["protocol"], "BOOT_ERROR=")
		var protocol_words: String = line_with(read(logs["protocol"]), "BOOT_ERROR=")
		check("another_protocol_is_refused_naming_both_protocols",
			line_with(read(logs["host"]), "code=wrong_protocol") != "" and protocol_words.contains(
				"protocol %d" % Net.PROTOCOL) and protocol_words.contains("speaks %d" % (Net.PROTOCOL - 1)),
			protocol_words)
		# REFUSED ON ITS PROTOCOL, NOT AS A HELLO NOBODY COULD READ: the host's row for it is `wrong_protocol`, and its
		# words are the ones the joiner was shown. (The garbled and oversized joiners are the `bad_hello`s.)
		var old_row: String = line_with(read(logs["host"]), "code=wrong_protocol")
		check("a_build_from_before_the_time_is_refused_on_its_protocol_as_older",
			protocol_words.contains("Yours is the older build: update yours.")
			and old_row.contains("Yours is the older build: update yours."), old_row)

		# ---- hellos that cannot be read ----
		await wait_for(logs["garbled"], "BOOT_ERROR=")
		await wait_for(logs["oversized"], "BOOT_ERROR=")
		var garbled: String = line_with(read(logs["garbled"]), "BOOT_ERROR=")
		var oversized: String = line_with(read(logs["oversized"]), "BOOT_ERROR=")
		check("a_hi_with_a_commit_no_build_has_is_refused_saying_so", garbled.contains("could not be read")
			and garbled.contains("commit") and garbled.contains(mine["line"]), garbled)
		check("a_hi_too_long_to_carry_is_refused_saying_so", oversized.contains("could not be read")
			and oversized.contains("over %d" % Net.HELLO_MOST_BYTES), oversized)
		check("and_nobody_refused_was_let_in", read(logs["host"]).count("NET_JOINED") == 2
			and read(logs["host"]).count("NET_REFUSED side=host") == 5,
			"%d joined, %d refused" % [read(logs["host"]).count("NET_JOINED"),
				read(logs["host"]).count("NET_REFUSED side=host")])

		# ---- a build older than the hi: this process, silent ----
		await _a_joiner_that_never_says_hi_is_told_why(port, mine)
		break
	await bury()
	check("a_port_was_available", port != 0, "port %d" % port if port != 0 else TestPorts.busy(FIRST_PORT, PORTS))
	await _a_join_nobody_answers_says_so()
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


## AN OLDER BUILD, AS FAR AS THE HOST CAN TELL: connected, and never a word. This process joins through `Net` and holds
## its hi back (`Net._pretend.silent`), which is exactly what a protocol-25 joiner does on the wire.
func _a_joiner_that_never_says_hi_is_told_why(port: int, mine: Dictionary) -> void:
	(Net.get("_pretend") as Dictionary)["silent"] = true
	Net.join("127.0.0.1", port)
	var since: int = Time.get_ticks_msec()
	while Net.transport != "none" and Time.get_ticks_msec() - since < Net.HI_WAIT_MSEC + 8000:
		await get_tree().process_frame
	(Net.get("_pretend") as Dictionary).erase("silent")
	var rows: Array[Dictionary] = Net.logbook.rows()
	var refused: Dictionary = rows[0] if not rows.is_empty() else {}
	check("a_joiner_that_never_says_hi_is_refused_as_older", Net.transport == "none"
		and String(refused.get("code", "")) == "no_hello" and Net.parting_words.contains("older")
		and Net.parting_words.contains(mine["line"]), "%s / '%s'" % [refused, Net.parting_words])
	Net.parting_words = ""


## NOBODY THERE: a port this checkout owns and nothing holds. ENet sits in CONNECTING for ever against one
## (working_with_godot.md); `Net`'s own deadline is what says no, in words that say where and how long.
func _a_join_nobody_answers_says_so() -> void:
	var nobody: int = TestPorts.first_free(FIRST_PORT, PORTS)
	Net.patience["connect"] = 2.0
	Net.join("127.0.0.1", nobody)
	var since: int = Time.get_ticks_msec()
	while Net.transport != "none" and Time.get_ticks_msec() - since < 8000:
		await get_tree().process_frame
	Net.patience["connect"] = Net.PATIENCE["connect"]
	var expected: String = "No answer from 127.0.0.1:%d after 2 s" % nobody
	check("a_join_nobody_answers_ends_in_words_saying_where_and_how_long", Net.transport == "none"
		and Net.parting_words.begins_with(expected) and String(Net.logbook.rows()[0].get("event", "")) == "TIMED_OUT",
		"'%s'" % Net.parting_words)
	Net.parting_words = ""


func spawn(project: String, log_path: String, user_args: Array[String]) -> int:
	var args: Array[String] = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file", log_path,
		"--path", project, "--"]
	args.append_array(user_args)
	return OS.create_process(OS.get_executable_path(), args)


## The host's JOINED rows. The same build and the one built later both join, so a count no longer says who.
func _joined_lines(text: String) -> Array:
	return Array(text.split("\n")).filter(func(row: String) -> bool: return row.begins_with("NET_JOINED"))


func read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## The first line holding `words`, and `and_words` too when it is given.
func line_with(text: String, words: String, and_words: String = "") -> String:
	for line in text.split("\n"):
		# `contains("")` is FALSE in Godot, so an empty `and_words` is asked about separately.
		if line.contains(words) and (and_words == "" or line.contains(and_words)):
			return line.strip_edges()
	return ""


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
