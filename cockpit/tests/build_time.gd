extends Node
## Headless: A BUILD KNOWS WHEN IT WAS MADE, SAYS HOW FAR IT IS FROM ANOTHER, AND THE CREW PAGE SHOWS WHO IS BEHIND.
##
##   Godot --headless --path cockpit res://tests/build_time.tscn
##
## Asked for on 2026-09-19, from a player: "put the current date into the build id that you check with the server so you
## can say who needs to update"; and the user: "store the build date and time and have that be sent over the wire (as
## epoch time) so we can tell clients and servers if someone has a newer or older build and how out of date it is."
## The export's half is `tests/build_export.gd`, the wire's is `tests/handshake_peers.gd`; this is the rest:
##
##   A DEV RUN'S TIME IS ITS COMMIT'S, read out of `.git` with no git process (`GitPack`), and it is what git says:
##     HEAD, and the last `COMMITS` commits one by one against `git log --format=%ct`, which on this repo's packs means
##     delta chains (a third of the packed commits are deltas); a commit made here with a set date, read LOOSE, then
##     read again once `git gc` has PACKED it                     RED with a delta applied wrong, or the pack skipped
##   HOW FAR APART, IN WORDS: "3 days older", "1 day newer", "5 hours older", "" under a minute or for an unknown time
##   THE CREW PAGE, started at the page a host looks at: a roster whose players are on builds two days older and five
##     hours newer than this one is drawn as two amber lines that say so, and a player on this build gets none
##                                                                  RED with the two times swapped in `Net.build_age_of`
##   A CARD'S BUILD TIME TRAVELS: a roster page read back off the wire keeps each player's time, and a card whose time
##     is not a time is dropped with a warning (rule 8)
##   "WHAT IS THE LATEST BUILD" IS OFF: its URL is empty, and asking makes no request and adds nothing to the tree. No
##     suite may touch the network.                               RED with a URL filled in
##
## Read RESULT=, not the exit code.

## How many commits back from HEAD are read and checked against git: enough to cross several delta chains. The newest
## commits are rarely deltas -- 1 in the last 60, 19 in the last 500 on 2026-09-19 -- so it reaches well back.
const COMMITS: int = 500
## The committer time given to the commit this suite makes in a scratch repository: 2026-09-19 12:34:56 UTC.
const MADE_AT: int = 1789821296

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[build_time] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_dev_time_is_the_commits()
	_every_commit_back_reads_as_git_reads_it()
	_a_loose_commit_and_then_the_same_one_packed()
	_how_far_apart_in_words()
	await _the_crew_page_says_who_is_on_another_build()
	_a_cards_build_time_travels()
	_the_latest_build_is_never_asked()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _git(arguments: Array) -> String:
	var said: Array = []
	var all: Array = ["-C", ProjectSettings.globalize_path("res://")]
	all.append_array(arguments)
	OS.execute("git", all, said, true)
	return String(said[0]).strip_edges() if not said.is_empty() else ""


## ---- a dev run's time ---------------------------------------------------------------------------------------------

func _the_dev_time_is_the_commits() -> void:
	var committed: int = int(_git(["log", "-1", "--format=%ct", "HEAD"]))
	# THE FIRST READ IS THE BOOT'S COST, measured cold: the plate's cache emptied, the file reads all done again.
	BuildPlate._dev_time = -1
	var since: int = Time.get_ticks_usec()
	var read: int = BuildPlate.time()
	var took: float = float(Time.get_ticks_usec() - since) / 1000.0
	_check("a_dev_runs_time_is_its_commits_as_git_says", committed > 0 and read == committed,
		"git %d, plate %d; the first read took %.2f ms" % [committed, read, took])


## EVERY COMMIT OF THE LAST `COMMITS`, read by `GitPack` and by git. The deltas are counted, so a run that happened to
## meet none says so rather than passing on whole objects alone.
func _every_commit_back_reads_as_git_reads_it() -> void:
	var common: String = BuildPlate.git_dirs(ProjectSettings.globalize_path("res://"))[1]
	var listed: PackedStringArray = _git(["log", "-%d" % COMMITS, "--format=%H %ct"]).split("\n", false)
	var wrong: PackedStringArray = []
	var since: int = Time.get_ticks_usec()
	for row in listed:
		var parts: PackedStringArray = row.split(" ")
		var read: int = GitPack.commit_time(common, parts[0])
		if read != int(parts[1]):
			wrong.append("%s: git %s, read %d" % [parts[0].substr(0, 8), parts[1], read])
	var took: float = float(Time.get_ticks_usec() - since) / 1000.0
	# WHICH OF THEM WERE DELTAS, asked of git: `%(deltabase)` names a base for a delta and zeroes for a whole object.
	var hashes: String = "\n".join(Array(listed).map(func(row: String) -> String: return row.get_slice(" ", 0)))
	var deltas: int = _deltas_among(hashes)
	_check("every_commit_back_reads_as_git_reads_it", listed.size() == COMMITS and wrong.is_empty() and deltas > 0,
		"%d commits, %d of them deltas, %.1f ms for all; %s" % [listed.size(), deltas, took,
			"all agree" if wrong.is_empty() else ", ".join(wrong.slice(0, 5))])
	_check("and_a_name_it_does_not_hold_reads_as_unknown",
		GitPack.commit_time(common, "0123456789abcdef0123456789abcdef01234567") == 0, "")


func _deltas_among(hashes: String) -> int:
	var list: String = OS.get_environment("TEMP").replace("\\", "/").path_join("build_time_hashes.txt")
	var file := FileAccess.open(list, FileAccess.WRITE)
	file.store_string(hashes + "\n")
	file.close()
	var said: Array = []
	# THROUGH cmd, for the stdin redirect: git's own batch mode reads names from stdin.
	OS.execute("cmd", ["/c", "git -C \"%s\" cat-file \"--batch-check=%%(deltabase)\" < \"%s\"" % [
		ProjectSettings.globalize_path("res://"), list.replace("/", "\\")]], said, true)
	var deltas: int = 0
	for row in (String(said[0]) if not said.is_empty() else "").split("\n", false):
		var base: String = row.strip_edges()
		if base.length() == 40 and base != "0".repeat(40):
			deltas += 1
	return deltas


## A COMMIT WITH A KNOWN TIME, in a scratch repository: read while it is a loose object, and again after `git gc` has
## put it in a pack. Both halves of the reader, on a commit whose answer is typed here rather than asked.
func _a_loose_commit_and_then_the_same_one_packed() -> void:
	var at: String = OS.get_environment("TEMP").replace("\\", "/").path_join("build_time_repo")
	_remove(at)
	DirAccess.make_dir_recursive_absolute(at)
	var run := func(arguments: Array) -> String:
		var said: Array = []
		var all: Array = ["-C", at, "-c", "user.name=build_time", "-c", "user.email=build_time@example.invalid",
			"-c", "core.autocrlf=false", "-c", "gc.auto=0"]
		all.append_array(arguments)
		OS.execute("git", all, said, true)
		return String(said[0]).strip_edges() if not said.is_empty() else ""
	run.call(["init", "-q"])
	OS.set_environment("GIT_COMMITTER_DATE", "@%d +0100" % MADE_AT)
	OS.set_environment("GIT_AUTHOR_DATE", "@%d +0100" % (MADE_AT - 3600))
	run.call(["commit", "-q", "--allow-empty", "-m", "a commit with a known time"])
	OS.unset_environment("GIT_COMMITTER_DATE")
	OS.unset_environment("GIT_AUTHOR_DATE")
	var head: String = run.call(["rev-parse", "HEAD"])
	var common: String = at.path_join(".git")
	var loose_file: bool = FileAccess.file_exists(common.path_join("objects").path_join(head.substr(0, 2)).path_join(
		head.substr(2)))
	var loose: int = GitPack.commit_time(common, head)
	run.call(["gc", "-q", "--prune=now"])
	var packed_away: bool = not FileAccess.file_exists(common.path_join("objects").path_join(head.substr(0, 2)).path_join(
		head.substr(2)))
	var packed: int = GitPack.commit_time(common, head)
	_check("a_loose_commit_reads_its_committer_time", loose_file and loose == MADE_AT,
		"loose file there %s; read %d, made %d (the author's hour earlier must not be read)" % [loose_file, loose, MADE_AT])
	_check("and_the_same_commit_once_packed", packed_away and packed == MADE_AT,
		"packed %s; read %d" % [packed_away, packed])
	_remove(at)


func _remove(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		OS.execute("cmd", ["/c", "rmdir", "/s", "/q", path.replace("/", "\\")], [])


## ---- words ------------------------------------------------------------------------------------------------------

func _how_far_apart_in_words() -> void:
	var now: int = 1789821296
	var cases: Array = [
		[now - 3 * 86400 - 600, "3 days older"], [now + 86400 + 7000, "1 day newer"], [now - 5 * 3600 - 59, "5 hours older"],
		[now + 12 * 60, "12 minutes newer"], [now - 60, "1 minute older"], [now + 59, ""], [now, ""], [0, ""],
	]
	var wrong: PackedStringArray = []
	for case in cases:
		var said: String = BuildPlate.age_words(int(case[0]), now)
		if said != String(case[1]):
			wrong.append("%+d s said '%s', wanted '%s'" % [int(case[0]) - now, said, case[1]])
	_check("how_far_apart_in_words", wrong.is_empty() and BuildPlate.age_words(now, 0) == "",
		"%d cases" % cases.size() if wrong.is_empty() else ", ".join(wrong))


## ---- the crew page ------------------------------------------------------------------------------------------------

## THE PAGE A HOST LOOKS AT, in a rig's own clipboard, handed the roster every machine holds. Two players are on builds
## of another age and one is on this one's; what is read is the glass's own labels.
func _the_crew_page_says_who_is_on_another_build() -> void:
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.clipboard.show_board(true)
	var page: ClipboardPage = rig.clipboard.page()
	page.show_tab(ClipboardPage.Tab.CREW)
	var mine: int = int(Net.identity()["built"])
	var was: Dictionary = Net.roster
	var me: int = Sim.local_client_id()
	Net.roster = {
		2: {"player": 2, "name": "ALICE", "colour": 1, "built": mine - 2 * 86400 - 300},
		3: {"player": 3, "name": "BOB", "colour": 2, "built": mine + 5 * 3600 + 30},
		4: {"player": 4, "name": "CAROL", "colour": 3, "built": mine + 20},
	}
	if me > 0:
		Net.roster[me] = {"player": me, "name": "HOST", "colour": 0, "built": mine}
	for i in range(3):
		page.tick()
		await get_tree().process_frame
	var lines: PackedStringArray = []
	for node in page.find_children("Build*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree():
			lines.append(label.text)
	var wanted: PackedStringArray = ["ALICE  ·  BUILD 2 DAYS OLDER THAN YOURS", "BOB  ·  BUILD 5 HOURS NEWER THAN YOURS"]
	_check("the_crew_page_says_who_is_on_another_build_and_by_how_much", mine > 0 and lines == wanted,
		"it says %s; wanted %s" % [lines, wanted])
	Net.roster = was
	page.tick()
	rig.clipboard.show_board(false)
	rig.queue_free()
	await get_tree().process_frame


## ---- the wire ---------------------------------------------------------------------------------------------------

func _a_cards_build_time_travels() -> void:
	var page: Dictionary = {"say": "roster", "n": 3, "page": 0, "pages": 1,
		"cards": [[2, "ALICE", 1, 1789821296], [3, "BOB", 2, 0]]}
	var heard: Dictionary = Net.read_hello(JSON.stringify(page).to_utf8_buffer())
	var cards: Array = heard.get("cards", [])
	_check("a_roster_page_keeps_each_players_build_time", cards.size() == 2
		and int((cards[0] as Dictionary).get("built", -1)) == 1789821296 and int((cards[1] as Dictionary).get("built", -1)) == 0,
		"%s" % [cards])
	page["cards"] = [[2, "ALICE", 1, "yesterday"]]
	_check("and_a_card_whose_time_is_not_a_time_is_dropped",
		Net.read_hello(JSON.stringify(page).to_utf8_buffer()).is_empty(), "")
	var hi: Dictionary = {"say": "hi", "protocol": Net.PROTOCOL, "commit": "unknown", "line": "dev", "built": -5}
	_check("and_so_is_a_hi_whose_time_is_not_a_time",
		Net.read_hello(JSON.stringify(hi).to_utf8_buffer()).is_empty() and Net.hello_fault.contains("build time"),
		"'%s'" % Net.hello_fault)


## ---- the latest build -------------------------------------------------------------------------------------------

func _the_latest_build_is_never_asked() -> void:
	var before: int = BuildStamp.find_children("*", "HTTPRequest", true, false).size()
	var asked: bool = BuildStamp.ask_for_the_latest_build()
	var after: int = BuildStamp.find_children("*", "HTTPRequest", true, false).size()
	_check("what_is_the_latest_build_is_planned_and_off", BuildStamp.LATEST_BUILD_URL.is_empty() and not asked
		and after == before, "url '%s', asked %s, %d requests before and %d after" % [BuildStamp.LATEST_BUILD_URL, asked,
			before, after])
