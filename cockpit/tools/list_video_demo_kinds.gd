extends Node
## PRINT THE DRAWN CRAFT WHOSE SIMULATION MODEL FLIES, for the fleet video wrapper.
##
## This deliberately asks the simulation instead of copying today's names into PowerShell.
## A new aeroplane, helicopter or tiltrotor therefore joins the next fleet render
## automatically. It runs as a project scene so the normal Sim autoload and native extension
## are ready; Godot's bare `--script` mode intentionally does not install those globals.

const FLYING_MODELS: PackedStringArray = ["airplane", "helicopter", "tiltrotor"]


func _ready() -> void:
	var names: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		var geometry: Dictionary = Sim.geometry_of(kind)
		if String(geometry.get("model_name", "")).to_lower() in FLYING_MODELS \
				and VehicleCatalogue.is_drawn(kind):
			names.append(Sim.kind_name(kind))
	print("VIDEO_DEMO_KINDS=%s" % ",".join(names))
	get_tree().quit()
