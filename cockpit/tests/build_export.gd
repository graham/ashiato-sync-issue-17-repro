extends Node
## Headless: a build made by the release script says, when it runs, which build it is -- not "dev".
##
##   Godot --headless --path cockpit res://tests/build_export.tscn
##
## THE REAL PATH, END TO END: `tools/release_beta.ps1 -ExportOnly` -- the same script, the same bake and the same
## `--export-release` a release goes through, stopping before the zip, the post and the commit -- into this checkout's
## TEMP, and then the exported Cockpit.exe itself is launched headless and its log read for the `BUILD=` line
## `BuildStamp` prints at boot. So what is checked is what the game believes about itself, read out of the pck, and not
## what the script meant to write. Then:
##
##   the build says "0.0.1 testing-tapir · <this commit> · <day>", not the dev line
##                                                                   RED with the bake line taken out of the script
##   the build knows WHEN it was built: the `BUILT=` epoch it prints, read out of the pck, is between the moments just
##     before and just after the export, and its line ends with that day (lane/buildtime, 2026-09-19)
##                                                                   RED with `build/time` not written by the script
##   BUILD_INFO.txt is beside the exe, with the same version, name and full commit, the build time and its epoch, the
##     engine and the exporting editor
##   project.godot is byte for byte what it was before the export: no commit hash is left in it
##   and `tools/export.ps1`, the dev build, says "dev · <this commit> · <when built>", never "dev · unknown"
##
## About 70 s: two exports of 30 to 38 s each and 3 s of each built game (2026-09-18, a lane, double editor). Read
## RESULT=, not the exit code.

const VERSION: String = "0.0.1"
## Verb-animal, as every release name is, and one no release will draw: "testing" is not in the script's verbs.
const NAME: String = "testing-tapir"
## Frames the exported game runs before it quits: enough to boot past the autoloads, which is where the line is printed.
const RUN_FRAMES: int = 120

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[build_export] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var settings: String = project.path_join("project.godot")
	var before: String = FileAccess.get_md5(settings)
	var said: Array = []
	OS.execute("git", ["-C", project, "rev-parse", "HEAD"], said)
	var head: String = String(said[0]).strip_edges() if not said.is_empty() else ""

	# THIS CHECKOUT'S OWN TEMP (run_all and every lane set it), so two lanes never export over each other.
	var out: String = OS.get_environment("TEMP").replace("\\", "/").path_join("cockpit_build_export")
	var script: String = project.path_join("tools/release_beta.ps1")
	var output: Array = []
	# THE WINDOW THE BUILD WAS MADE IN, whole seconds either side: its baked time must fall inside it.
	var before_export: int = int(Time.get_unix_time_from_system())
	var code: int = OS.execute("powershell", ["-NoProfile", "-File", script.replace("/", "\\"), "-Version", VERSION,
		"-Name", NAME, "-ExportOnly", "-NoMusic", "-OutDir", out.replace("/", "\\")], output, true)
	var spoke: String = "\n".join(output)
	var after_export: int = int(Time.get_unix_time_from_system()) + 1
	var exe: String = out.path_join("Cockpit.exe")
	_check("the_script_exported_a_build", code == 0 and FileAccess.file_exists(exe)
		and FileAccess.file_exists(out.path_join("Cockpit.pck")), "exit %d: %s" % [code, spoke.strip_edges().right(400)])
	_check("project_godot_is_as_it_was", FileAccess.get_md5(settings) == before,
		"md5 %s before, %s after" % [before, FileAccess.get_md5(settings)])

	var info: String = FileAccess.get_file_as_string(out.path_join("BUILD_INFO.txt"))
	var missing: PackedStringArray = []
	for row in ["version:     " + VERSION, "name:        " + NAME, "commit:      " + head, "engine:      Godot 4.7.2",
			"exported by: ", "music:       ", "host voice:  "]:
		if not info.contains(row):
			missing.append(row.strip_edges())
	_check("build_info_txt_says_what_the_folder_is", head.length() == 40 and missing.is_empty(),
		"missing %s" % [missing])

	var line: String = _what_it_says(exe)
	var built: int = _when_it_says(exe)
	var wanted: String = "%s %s%s%s%s%s" % [VERSION, NAME, BuildPlate.DOT, head.substr(0, BuildPlate.SHORT),
		BuildPlate.DOT, BuildPlate.date_of(built)]
	_check("the_built_game_says_it_is_the_release", built > 0 and line == wanted,
		"it said '%s', wanted '%s'" % [line, wanted])
	_check("the_built_game_knows_when_it_was_built", built >= before_export and built <= after_export,
		"BUILT=%d; the export ran from %d to %d" % [built, before_export, after_export])
	_check("and_build_info_says_the_same_time", info.contains("built:       %s (epoch %d)" % [BuildPlate.when_of(built),
		built]), "wanted 'built:       %s (epoch %d)' in BUILD_INFO.txt" % [BuildPlate.when_of(built), built])
	_check("the_built_game_is_not_a_dev_run", not line.is_empty() and not line.begins_with("dev"), "'%s'" % line)

	# THE OTHER WAY A BUILD IS MADE: tools/export.ps1, a dev build. It must say which commit it was built from -- an
	# exported game has no .git to read, and before 2026-09-18 this path baked nothing and its builds said "dev · unknown".
	var dev_out: String = OS.get_environment("TEMP").replace("\\", "/").path_join("cockpit_build_export_dev")
	output.clear()
	code = OS.execute("powershell", ["-NoProfile", "-File", project.path_join("tools/export.ps1").replace("/", "\\"),
		"-OutDir", dev_out.replace("/", "\\")], output, true)
	_check("project_godot_is_as_it_was_after_the_dev_build", FileAccess.get_md5(settings) == before,
		"md5 %s before, %s after" % [before, FileAccess.get_md5(settings)])
	var dev_line: String = _what_it_says(dev_out.path_join("Cockpit.exe"))
	var dev_wanted: String = "dev%s%s%s" % [BuildPlate.DOT, head.substr(0, BuildPlate.SHORT), BuildPlate.DOT]
	_check("a_dev_build_says_dev_and_its_commit", code == 0 and dev_line.begins_with(dev_wanted),
		"exit %d; it said '%s', wanted '%s<when built>'" % [code, dev_line, dev_wanted])

	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## THE BUILT TIME the same run printed, `BUILT=`: what the pck carries, read by the game itself. 0 if it said none.
func _when_it_says(exe: String) -> int:
	for row in FileAccess.get_file_as_string(exe.get_base_dir().path_join("run.log")).split("\n"):
		if row.begins_with("BUILT="):
			return int(row.trim_prefix("BUILT=").strip_edges())
	return 0


## THE BUILT GAME, RUN, and the `BUILD=` line it printed at boot, or "". A release template is a windowed program whose
## stdout goes nowhere, so it writes a log file.
func _what_it_says(exe: String) -> String:
	var log: String = exe.get_base_dir().path_join("run.log")
	DirAccess.remove_absolute(log)
	if FileAccess.file_exists(exe):
		OS.execute(exe, ["--headless", "--xr-mode", "off", "--quit-after", str(RUN_FRAMES), "--log-file", log], [])
	var line: String = ""
	for row in FileAccess.get_file_as_string(log).split("\n"):
		if row.begins_with("BUILD="):
			line = row.trim_prefix("BUILD=").strip_edges()
	return line
