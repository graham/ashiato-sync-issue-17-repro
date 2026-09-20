extends Node
## Headless: A DRAWN LINE NEVER SHOWS THROUGH A MOUNTAIN FROM A CHASE CAMERA, and the game itself never draws with the depth
## test off.
##
##   Godot --headless --path cockpit res://tests/seethrough.tscn
##
## THE FAULT (the user, 2026-09-19, on the P-51 trip: "landing strips were visible THROUGH the mountains, i think there is a
## zbuffer issue"). It was not the game's depth buffer. `tests/pattern_shot.gd` draws the strip it flies to, the pattern's legs
## and the aeroplane's track as flat lines, and it drew them with `no_depth_test`, priority 10, so they showed over
## everything -- which is right in a picture taken straight down and wrong from the chase camera the trip is seen from, where
## the south shore strip's outline lay over the ridge the aeroplane was crossing. The game's own runway was measured from 134
## eyes behind rock, day and night, and is hidden by the mountain from every one (`tests/seethrough_shot.gd`).
##
## - THE CHASE SCENE TESTS THE DEPTH BUFFER: the material `pattern_shot` makes for a line in the `trip` scene has the depth
##   test on, and in every scene that looks straight down it is off, because a track flown at 400 m has to show over a 1,000 m
##   peak on a map.
## - THE GAME NEVER TURNS THE DEPTH TEST OFF ON ITS SCENERY: of the game's own shaders, only the mist and the puffs say
##   `depth_test_disabled` (they read the depth buffer themselves), so no runway, paint, light or mountain shader can draw
##   through the rock. A new one has to be named here, with its reason.
## Read RESULT=, not the exit code.

## THE SHADERS ALLOWED TO DRAW WITH THE DEPTH TEST OFF, and why.
const DEPTH_TEST_OFF_BECAUSE: Dictionary = {
	"mist.gdshader": "the mist reads the depth texture itself and fogs by it",
	"puff.gdshader": "each chord is ended at the depth buffer's surface in the shader, so the world cuts the cloud",
}
const SCENES_LOOKING_DOWN: Array[String] = ["one", "two", "mixed"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[seethrough] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var shot: GDScript = load("res://tests/pattern_shot.gd")
	var chase: StandardMaterial3D = shot.call("_flat", Color.WHITE, shot.call("draws_on_top", "trip"))
	_check("a_line_in_the_chase_scene_is_tested_against_the_depth_buffer", not chase.no_depth_test,
		"no_depth_test=%s" % chase.no_depth_test)
	for scene in SCENES_LOOKING_DOWN:
		var plan: StandardMaterial3D = shot.call("_flat", Color.WHITE, shot.call("draws_on_top", scene))
		_check("a_line_in_the_%s_scene_shows_over_the_peaks" % scene, plan.no_depth_test,
			"no_depth_test=%s" % plan.no_depth_test)
	var off: PackedStringArray = []
	for file in DirAccess.get_files_at("res://world/shaders"):
		if not (file.ends_with(".gdshader") or file.ends_with(".gdshaderinc")):
			continue
		var source: String = FileAccess.get_file_as_string("res://world/shaders/" + file)
		for line in source.split("\n"):
			if line.begins_with("render_mode") and line.contains("depth_test_disabled"):
				off.append(file)
	off.sort()
	var allowed: PackedStringArray = PackedStringArray(DEPTH_TEST_OFF_BECAUSE.keys())
	allowed.sort()
	_check("only_the_mist_and_the_puffs_draw_with_the_depth_test_off", off == allowed,
		"drawn with it off: %s; allowed: %s" % [off, allowed])
	_finish()


func _finish() -> void:
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
