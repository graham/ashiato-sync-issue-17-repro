extends RefCounted
class_name BuildPlate
## WHICH BUILD THIS IS: the version, the release name, the commit and the date, and the one line that says them.
##
## Asked for on 2026-09-18: "we need a ui element in the game that is always visible and visible in every screenshot
## and video, so we know what build a screenshot, video came from. And a player is playing we can ask them, 'what build
## are you on'." Named for an aircraft's DATA PLATE, the riveted plate that says what type it is and which one. This is
## the one place that answers; `BuildStamp` (the lower right of the desktop) and the clipboard's bezel only read it.
##
## ---------------------------------------------------------------------------------
## A RELEASE IS BAKED IN; A DEV RUN READS THE CHECKOUT
## ---------------------------------------------------------------------------------
##
## A RELEASE carries its identity as PROJECT SETTINGS, written by `tools/release_beta.ps1` just before it exports and
## taken out of project.godot again the moment the export is done. Settings go into the pck as project.binary with
## everything else the project says about itself, so there is no export filter to forget -- a generated res:// file was
## the alternative, and a non-resource file is left out of an `all_resources` export unless the include filter names it,
## which is one more thing that could quietly not ship. The script restores project.godot on every path out, including a
## failed export, so no commit hash is ever committed: a hash written into the commit it names is impossible anyway.
## `version` is `application/config/version`, the setting Godot already has and the script already wrote.
##
## A DEV RUN (the editor, a suite, a lane) has none of that, and reads the commit from the checkout's own `.git`: HEAD,
## then the ref it names, loose or packed. A worktree's `.git` is a FILE naming its gitdir, whose `commondir` holds the
## refs, and every lane here is a worktree, so that is the case this is written for. NO "+dirty": `git status` on this
## repo took 65 to 187 ms (three runs, 2026-09-18, a lane), plus a process start, at every boot of every suite, for a
## word the probes that care already write into their own captions. `line()` STILL says none: it is what the handshake
## compares, and two lanes at one commit must stay one build. But the STAMP now does, through `shown_line()`, asked once
## and only where a picture can be taken (see "DIRTY" below), because on 2026-09-20 `lane/rivers` shot from a modified
## tree, the stamp printed the previous commit, and a frame nearly went on the blog as the result of work it predated.
##
## ---------------------------------------------------------------------------------
## THE LINE
## ---------------------------------------------------------------------------------
##
##   0.2.1 leaping-llama · 3631368a · 2026-09-19     a release, dated the day it was built (UTC)
##   dev · 9920fed4 · 2026-09-18                     a dev run, dated by its commit; a dev export, by its build
##
## What a player reads out when asked "what build are you on", so it starts with what they would say. The date was
## added on 2026-09-19, from a player: "put the current date into the build id that you check with the server so you
## can say who needs to update". Until then a release line had no date, and a dev line carried the day it RAN, which
## said nothing about the build.
##
## ---------------------------------------------------------------------------------
## WHEN IT WAS BUILT: ONE NUMBER, EPOCH SECONDS UTC
## ---------------------------------------------------------------------------------
##
## `time()` is the one answer, and everything that shows or compares a build's age reads it: the date on the line, the
## `built` the handshake says (`Net.identity`), the words that say who is older (`age_words`), the CREW page. A release
## and a dev export bake it (`TIME_SETTING`, written by `tools/release_beta.ps1` the moment it reads the commit). A DEV
## RUN reads its COMMIT'S committer time out of `.git` (`GitPack.commit_time`): the same on every machine at that commit,
## so two lanes at one commit are the same age to the second, and no git process is started to learn it. The day the
## game ran, and the time HEAD moved (the reflog), were the rejected alternatives: both differ by machine for one build.
## 0 is "unknown" (a checkout it cannot read), and nothing is dated or compared from it.

## THE SETTINGS A RELEASE IS BAKED WITH. `tools/release_beta.ps1` writes these exact keys; `tests/build_stamp.gd` fails
## if the script stops naming any of them, so the two cannot drift apart.
const VERSION_SETTING: String = "application/config/version"
const NAME_SETTING: String = "application/build/name"
const COMMIT_SETTING: String = "application/build/commit"
const BRANCH_SETTING: String = "application/build/branch"
## When the build was made, EPOCH SECONDS UTC, an int. It replaced `application/build/date`, a local
## "2026-09-18 14:03" string, on 2026-09-19: two machines can subtract a number, and it is in one time zone.
const TIME_SETTING: String = "application/build/time"
## How much of a commit hash the line shows: what `git log --oneline` shows in this repo.
const SHORT: int = 8
const DOT: String = " · "

## The dev commit, read once: the checkout does not change under a running game in a way worth a second read.
static var _dev_commit: String = ""
## The dev commit's own time, read once; -1 until something has asked.
static var _dev_time: int = -1
## Builds closer together than this are the same age: two exports of one commit a few seconds apart are.
const SAME_AGE_SECONDS: int = 60


## Whether this is a released build: the release script baked a name and a commit in. A DEV EXPORT
## (`tools/export.ps1`, which is `release_beta.ps1 -ExportOnly -Dev`) bakes the commit and the date but no name, and
## says "dev" with the commit it was built from rather than "unknown": an exported game has no `.git` to read.
static func is_release() -> bool:
	return not commit_baked().is_empty() and not release_name().is_empty()


static func version() -> String:
	return String(ProjectSettings.get_setting(VERSION_SETTING, ""))


## The release's name, "leaping-llama", or "" in a dev run.
static func release_name() -> String:
	return String(ProjectSettings.get_setting(NAME_SETTING, ""))


## The full commit the release was built from, or "" in a dev run.
static func commit_baked() -> String:
	return String(ProjectSettings.get_setting(COMMIT_SETTING, ""))


## The full commit: baked in a release, read from the checkout in a dev run, "unknown" if neither can say.
static func commit() -> String:
	if not commit_baked().is_empty():
		return commit_baked()
	if _dev_commit.is_empty():
		_dev_commit = read_checkout(ProjectSettings.globalize_path("res://"))
		if _dev_commit.is_empty():
			_dev_commit = "unknown"
	return _dev_commit


static func branch() -> String:
	return String(ProjectSettings.get_setting(BRANCH_SETTING, ""))


## WHEN THIS BUILD WAS MADE, epoch seconds UTC: baked in an export, the commit's own time in a dev run, 0 if neither can
## say. See "WHEN IT WAS BUILT" at the top.
static func time() -> int:
	var baked: int = int(ProjectSettings.get_setting(TIME_SETTING, 0))
	if baked > 0:
		return baked
	if _dev_time < 0:
		_dev_time = 0
		var dirs: PackedStringArray = git_dirs(ProjectSettings.globalize_path("res://"))
		if not dirs.is_empty() and commit() != "unknown":
			_dev_time = GitPack.commit_time(dirs[1], commit())
	return _dev_time


## The day it was built, "2026-09-19", in UTC, or "" when nobody knows.
static func date() -> String:
	return date_of(time())


static func date_of(epoch: int) -> String:
	return Time.get_date_string_from_unix_time(epoch) if epoch > 0 else ""


## "2026-09-19 14:03 UTC", or "unknown": the long form, for a log.
static func when_of(epoch: int) -> String:
	if epoch <= 0:
		return "unknown"
	return Time.get_datetime_string_from_unix_time(epoch, true).left(16) + " UTC"


## THE LINE: what the lower right of the screen and the clipboard both say. See the note at the top.
static func line() -> String:
	return _line("")


## THE LINE AS A PICTURE SHOULD SAY IT: `line()` with " +dirty" after the commit when the checkout has changes the commit
## does not, as `run_all.ps1` words it ("Ran on main <sha> +dirty"). Never for the handshake; that is `line()`.
static func shown_line() -> String:
	return _line(DIRTY_WORD if dirty() else "")


## ---------------------------------------------------------------------------------
## DIRTY: THE PICTURE MAY BE OF CODE THAT IS NOT THE COMMIT
## ---------------------------------------------------------------------------------
##
## Shooting is how you decide whether to commit, so most pictures are taken from a tree that differs from HEAD, and the
## sha alone then names the wrong code. `git status --porcelain`, the runner's own test (untracked files count), run ONCE
## (cached) and NEVER where it cannot mean anything: a release or a dev export (a baked commit: no checkout, and never a
## process started), a checkout with no `.git`, and a HEADLESS run, which takes no picture and would pay 65 to 187 ms at
## every suite boot for nothing. `dirty_in` is the uncached test, public so a suite can hand it a repo it made.
const DIRTY_WORD: String = " +dirty"
## -1 until asked, then 0 or 1.
static var _dirty: int = -1


static func dirty() -> bool:
	if _dirty < 0:
		_dirty = 0
		if commit_baked().is_empty() and DisplayServer.get_name() != "headless":
			_dirty = 1 if dirty_in(worktree_of(ProjectSettings.globalize_path("res://"))) else 0
	return _dirty == 1


## Whether the git checkout at `worktree` has anything `git status --porcelain` lists; false when there is no git to ask.
static func dirty_in(worktree: String) -> bool:
	if git_dirs(worktree).is_empty():
		return false
	var said: Array = []
	if OS.execute("git", ["-C", worktree, "status", "--porcelain"], said) != 0 or said.is_empty():
		return false
	return not String(said[0]).strip_edges().is_empty()


static func _line(mark: String) -> String:
	var short: String = commit().substr(0, SHORT) + mark
	var dated: String = (DOT + date()) if not date().is_empty() else ""
	if is_release():
		return "%s %s%s%s%s" % [version(), release_name(), DOT, short, dated]
	return "dev%s%s%s" % [DOT, short, dated]


## ---------------------------------------------------------------------------------
## WHERE THE PICTURE WAS TAKEN: THE LANE AND THE WORKTREE, READ OFF THE RUNNING PROJECT'S OWN PATH
## ---------------------------------------------------------------------------------
##
## Asked for on 2026-09-19: "have the worktree path and team mate name in all screenshots and videos" -- a dozen pictures a
## night from nine lanes, and nobody can say which worktree made which. So a dev run's stamp says it:
##
##   dev · 9920fed4 · 2026-09-18 · lane/harrier · C:\gg-wt\harrier
##   dev · 9920fed4 · 2026-09-18 · main · C:\Users\Graham\Desktop\godotgames
##
## DERIVED, NEVER TYPED OR PASSED IN: the worktree is the folder above the project (`res://` is `<worktree>/cockpit`), and
## the lane is that folder's name when it sits directly under `gg-wt` (the lanes' parent folder, `LANES_FOLDER`), and
## "main" for anything else, which is the shared checkout. No environment variable, so a tool that forgets to set one
## cannot make a lane's picture say "main". It is NOT part of `line()`: the line is what the handshake compares between
## peers, and two lanes at one commit must stay the same build. A RELEASE says nothing here: it has no checkout, and a
## player's folder is theirs.
const LANES_FOLDER: String = "gg-wt"


## The worktree that holds `project_dir` (the folder with project.godot in it), forward slashes, no trailing one.
static func worktree_of(project_dir: String) -> String:
	return project_dir.replace(char(92), "/").rstrip("/").get_base_dir()


## The lane a worktree is: "lane/<folder>" under `LANES_FOLDER`, else "main".
static func lane_of(worktree: String) -> String:
	var clean: String = worktree.replace(char(92), "/").rstrip("/")
	if clean.get_base_dir().get_file().to_lower() == LANES_FOLDER:
		return "lane/" + clean.get_file()
	return "main"


## THE WORDS FOR ONE WORKTREE: "lane/harrier · C:\gg-wt\harrier", the path in Windows' own slashes there.
static func words_for(worktree: String) -> String:
	var shown: String = worktree.replace("/", char(92)) if OS.get_name() == "Windows" else worktree
	return lane_of(worktree) + DOT + shown


## What this running project says of itself, or "" in a release.
static func where() -> String:
	if is_release():
		return ""
	return words_for(worktree_of(ProjectSettings.globalize_path("res://")))


## ---------------------------------------------------------------------------------
## HOW MUCH OLDER OR NEWER
## ---------------------------------------------------------------------------------

## A LENGTH OF TIME AS A PLAYER SAYS IT: "3 days", "1 day", "5 hours", "12 minutes". The largest whole unit, rounded
## down, because "1 day" for 47 hours is honest and "2 days" is not.
static func how_long(seconds: int) -> String:
	seconds = absi(seconds)
	for unit in [[86400, "day"], [3600, "hour"], [60, "minute"]]:
		var count: int = seconds / int(unit[0])
		if count >= 1:
			return "%d %s%s" % [count, unit[1], "" if count == 1 else "s"]
	return "less than a minute"


## HOW `theirs` STANDS AGAINST `mine`, in words about THEIRS: "3 days older", "5 hours newer", or "" when the two are
## the same age (within `SAME_AGE_SECONDS`) or either is unknown. Pure, so every side of the handshake says it alike.
static func age_words(theirs: int, mine: int) -> String:
	if theirs <= 0 or mine <= 0 or absi(theirs - mine) < SAME_AGE_SECONDS:
		return ""
	return "%s %s" % [how_long(theirs - mine), "older" if theirs < mine else "newer"]


## THE COMMIT A CHECKOUT IS AT, from its files alone, or "" if `from` is in none. Walks up from `from` to the first
## `.git`, file or folder. Public so a suite can hand it a checkout it built.
static func read_checkout(from: String) -> String:
	var dirs: PackedStringArray = git_dirs(from)
	if dirs.is_empty():
		return ""
	var gitdir: String = dirs[0]
	var common: String = dirs[1]
	var head: String = FileAccess.get_file_as_string(gitdir.path_join("HEAD")).strip_edges()
	if not head.begins_with("ref:"):
		return head if _is_a_hash(head) else ""
	var ref: String = head.trim_prefix("ref:").strip_edges()
	for where in [gitdir, common]:
		var loose: String = String(where).path_join(ref)
		if FileAccess.file_exists(loose):
			var hash: String = FileAccess.get_file_as_string(loose).strip_edges()
			if _is_a_hash(hash):
				return hash
	var packed: String = common.path_join("packed-refs")
	if FileAccess.file_exists(packed):
		for row in FileAccess.get_file_as_string(packed).split("\n"):
			var parts: PackedStringArray = row.strip_edges().split(" ")
			if parts.size() == 2 and parts[1] == ref and _is_a_hash(parts[0]):
				return parts[0]
	return ""


## THE CHECKOUT'S GIT FOLDERS, [gitdir, common], or [] if `from` is in none. Walks up from `from` to the first `.git`,
## file or folder. HEAD is in `gitdir`; the shared refs and every object are in `common`, which is the same folder
## except in a worktree.
static func git_dirs(from: String) -> PackedStringArray:
	var at: String = from.replace("\\", "/").trim_suffix("/")
	var git: String = ""
	while not at.is_empty():
		var here: String = at + "/.git"
		if DirAccess.dir_exists_absolute(here) or FileAccess.file_exists(here):
			git = here
			break
		var up: String = at.get_base_dir()
		if up == at:
			break
		at = up
	if git.is_empty():
		return PackedStringArray()
	# A WORKTREE: `.git` is a file, "gitdir: <path>", and that gitdir's `commondir` says where the shared refs are.
	var gitdir: String = git
	if FileAccess.file_exists(git):
		var said: String = FileAccess.get_file_as_string(git).strip_edges()
		if not said.begins_with("gitdir:"):
			return PackedStringArray()
		gitdir = said.trim_prefix("gitdir:").strip_edges().replace("\\", "/")
		if gitdir.is_relative_path():
			gitdir = at.path_join(gitdir).simplify_path()
	var common: String = gitdir
	var pointer: String = gitdir.path_join("commondir")
	if FileAccess.file_exists(pointer):
		var to: String = FileAccess.get_file_as_string(pointer).strip_edges().replace("\\", "/")
		common = (to if not to.is_relative_path() else gitdir.path_join(to)).simplify_path()
	return PackedStringArray([gitdir, common])


static func _is_a_hash(text: String) -> bool:
	return text.length() >= 40 and text.is_valid_hex_number(false)
