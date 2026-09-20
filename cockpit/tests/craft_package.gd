extends Node
const KIND := Sim.Kind.PLANE
var _failures: PackedStringArray = []
func _check(label: String, ok: bool, detail: String) -> void:
	print("[craft_package] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: _failures.append(label)
func _ready() -> void:
	var station := (VehicleCatalogue.seat_scene(KIND) as PackedScene).instantiate() as CockpitStation
	add_child(station); station.fit(0, true, KIND, false)
	_check("this_suite_uses_its_own_package_folder", CraftPackage.folder == CraftPackage.TEST_ROOT + CockpitLayout.test_slot(), CraftPackage.folder)
	var saved := CraftPackage.write_station(KIND, 0, station, "suite")
	_check("writes_a_versioned_package", not saved.has("error"), str(saved))
	var read := CraftPackage.read_station(KIND, 0, "suite")
	_check("reopens_the_same_station", not read.has("error") and (read.get("layout", {}) as Dictionary).get("controls", []).size() == CockpitLayout.of_station(KIND, 0, station).get("controls", []).size(), str(read))
	_check("refuses_a_package_for_another_craft", CraftPackage.read_station(Sim.Kind.BOAT, 0, "suite").has("error"), "boat may not install plane")
	station.queue_free(); print("[craft_package] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL")); get_tree().quit(0 if _failures.is_empty() else 1)
