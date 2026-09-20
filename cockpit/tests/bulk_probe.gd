extends "res://tests/crowd.gd"
## Full exploratory ladder. It prints measurements and deliberately has no verdict; the
## bounded production gate is bulk_load. Use --ladder=full or --most=N.


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("[bulk_probe] extension missing")
		get_tree().quit(1)
		return
	var counts: PackedInt32Array = [0, 50, 100, 200]
	var full := false
	var only_max := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--ladder=full":
			full = true
		elif arg.begins_with("--most="):
			var most := maxi(0, int(arg.get_slice("=", 1)))
			counts = PackedInt32Array([0, mini(50, most), mini(100, most), most])
		elif arg == "--only-max":
			only_max = true
	if only_max:
		counts = PackedInt32Array([counts[counts.size() - 1]])
	var peers: PackedInt32Array = [2, 4, 8] if full else [2]
	var links: PackedInt32Array = [8, 16] if full else [8]
	for link in links:
		for peer_count in peers:
			for craft in counts:
				run_bulk_cell(mini(craft, HoldingStack.MOST), peer_count, link, 600, 1200)
	print("[bulk_probe] complete; BULK lines above are the table")
	get_tree().quit()
