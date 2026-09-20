extends Node
## A SURVEY, NOT A SUITE (lane/rivers, 2026-09-20): what the generated ground's lakes actually are on every level that
## has them, and whether the sea shader's "still inside the coast" band covers them.
##
##   Godot --headless --path cockpit res://tests/rivers_survey.tscn
##
## `WaterSurface.dressed` hands every water surface `land_half = Terrain.WORLD_HALF` (7,200 m), the ISLAND level's
## half-width, whatever level is being flown. Both ocean shaders fade their motion in over `offshore` 40 m to 260 m,
## where `offshore = max(|x|, |z|) - land_half`. So a lake further out than 7,460 m in the max-norm is given the open
## sea's motion. This prints, per level, every lake and which side of that line it falls.
##
## WHAT IT FOUND, 2026-09-20: 30 of the 54 lakes on the five generated levels are outside the still band, at motion
## factor 1.00 of full -- alpine's lake at (-15264, -2327) is 15.3 km out, and stands at 27 m. `lake_sheets.gd`'s doc
## block says the opposite in so many words ("the lakes are inside the coast band, where both ocean shaders move
## nothing, so a lake is flat"), which is true on the island level and false on every generated one. The lake sheet
## heaves with the open sea's swell while `Terrain.water_height`, which the hull floats on, stays flat.
##
## AND IT FIRST PASSED WITH 0 LAKES. `JSON.parse_string` gives every number as a float, `GroundField.configure`
## refuses "world_half is not an int", and the catalogue came back empty on all five levels -- a green run that had
## measured nothing, which is the trap `testing_godot_headless.md` names. The tuning is read as ints now, and the
## RESULT line FAILS on a run that catalogued no lakes at all.

const STILL_NEAR: float = 40.0
const STILL_GONE: float = 260.0


func _ready() -> void:
	var land_half: float = Terrain.WORLD_HALF
	print("[survey] land_half handed to every water shader = %.0f m; motion is full past %.0f m in the max-norm"
		% [land_half, land_half + STILL_GONE])
	var moving: int = 0
	var total: int = 0
	for id in ["alpine", "adriatic", "gliders", "testfield", "trace"]:
		var file := FileAccess.open("res://levels/%s/level.json" % id, FileAccess.READ)
		if file == null:
			continue
		var level: Dictionary = JSON.parse_string(file.get_as_text())
		if not level.has("ground"):
			continue
		var tuning: Dictionary = {}
		for key in (level["ground"] as Dictionary):
			tuning[key] = int((level["ground"] as Dictionary)[key])
		var ground: Object = ClassDB.instantiate("GroundField")
		var problems: PackedStringArray = ground.call("configure", tuning)
		var lakes: Array = (ground.call("catalogue") as Dictionary).get("lakes", [])
		print("[survey] %s: ground %s, problems %s -- %d lakes" % [id, tuning, problems, lakes.size()])
		for entry in lakes:
			var lake: Dictionary = entry
			var x: float = float(int(lake["x"]))
			var z: float = float(int(lake["z"]))
			var out: float = maxf(absf(x), absf(z))
			var motion: float = smoothstep(land_half + STILL_NEAR, land_half + STILL_GONE, out)
			total += 1
			if motion > 0.0:
				moving += 1
			print("[survey]   lake at (%6d, %6d) r %4d m, water_radius %4d m, level %6.1f m, depth %5.1f m"
				% [x, z, int(lake["r"]), int(lake.get("water_radius", 0)), float(int(lake["level"])) / 1024.0,
					float(int(lake["depth"])) / 1024.0])
			print("[survey]     max-norm %7.0f m from the origin -> the sea shader moves it by %.2f of full"
				% [out, motion])
	print("[survey] %d of %d lakes on the generated levels are OUTSIDE the still band" % [moving, total])
	# A SURVEY THAT FOUND NOTHING IS NOT A SURVEY: 0 lakes means the tuning was refused, not that the world has none.
	print("RESULT=%s survey printed %d lakes" % ["PASS" if total > 0 else "FAIL no lakes catalogued at all", total])
	get_tree().quit(0)
