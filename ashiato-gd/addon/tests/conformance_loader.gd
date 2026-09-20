extends Node
## Loads the checks only after the native class exists.
##
## Referring to an absent GDExtension class is a GDScript parse error. When this scene
## pointed straight at conformance.gd, a missing DLL prevented _ready() from existing,
## so the intended class_registered failure never ran and the process waited forever.


func _ready() -> void:
	if not ClassDB.class_exists(&"AshiatoWorld"):
		print("[conformance] FAIL class_registered "
			+ "(the GDExtension did not register AshiatoWorld)")
		print("[conformance] RESULT=FAIL [class_registered]")
		get_tree().quit(1)
		return

	var checks_script := load("res://tests/conformance.gd") as Script
	if checks_script == null:
		print("[conformance] FAIL checks_loaded (res://tests/conformance.gd did not load)")
		print("[conformance] RESULT=FAIL [checks_loaded]")
		get_tree().quit(1)
		return
	add_child(checks_script.new())
