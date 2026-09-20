extends Node
## Headless probe: the three helicopters' native geometry, seats and every drawn mesh's vertex box. Read RESULT=.

func _ready() -> void:
	CockpitStation.use_saved_layouts = false
	for kind in [Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.CHINOOK]:
		var g: Dictionary = Sim.geometry_of(kind)
		print("[rotor_probe] ==== %s" % Sim.kind_name(kind))
		for key in g:
			if key == "seat_poses":
				for pose in g[key]: print("[rotor_probe]   seat %s" % [pose])
			else:
				print("[rotor_probe]   %s = %s" % [key, g[key]])
		var scene := load("res://objects/vehicles/craft_%s.tscn" % Sim.kind_name(kind)) as PackedScene
		var view := scene.instantiate() as VehicleView
		add_child(view); view.preview_kind = kind; view._show_in_editor()
		for child in view.find_children("*", "MeshInstance3D", true, false):
			var drawn := child as MeshInstance3D
			if drawn.mesh == null or not drawn.is_visible_in_tree(): continue
			var into := view.global_transform.affine_inverse() * drawn.global_transform
			var box := AABB(); var any := false
			for s in range(drawn.mesh.get_surface_count()):
				for p in drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
					var at: Vector3 = into * p; box = box.expand(at) if any else AABB(at, Vector3.ZERO); any = true
			print("[rotor_probe]   mesh %-40s %s .. %s" % [String(view.get_path_to(drawn)).right(60), box.position.snapped(Vector3.ONE*0.01), box.end.snapped(Vector3.ONE*0.01)])
		view.queue_free()
	print("RESULT=PASS")
	get_tree().quit(0)
