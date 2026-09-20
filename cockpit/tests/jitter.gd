extends Node
## HOW FINE A GRID THE PICTURE IS DRAWN ON, HERE AND OUT THERE.
##
## The simulation is not the suspect: measured, an aeroplane's path is exactly as smooth at
## the far corner as it is at the origin, with or without the carrier in the world, and the
## client is not being rolled back at all. What is left is the one thing that changes with
## distance from the origin and nothing else -- the size of a float.
##
## A float32 holds about seven digits. Near the origin that is microns; nine kilometres out
## the gap between one representable number and the next is a millimetre, and EVERY world
## position downstream lands on that grid: the vehicle, the seat, the instrument panel, the
## camera matrix. Your head moves smoothly and the cockpit is redrawn on a millimetre grid.
##
## This measures that grid the way the renderer sees it -- through a real Transform3D, at a
## real cockpit offset -- rather than asserting it.
##
## WHAT IT SAYS NOW: nothing measurable at any distance, out to the edge of the map. The
## engine is built with `precision=double` -- see agents.md -- so `real_t` is a double.
## Before that it read 0.12 mm at 2 km, 0.49 mm at the carrier and 0.98 mm at the map edge.
## Run it against the stock editor in `_tools/godot-4.7.2` to see those numbers come back.
##
## THE PROCESSOR'S HALF ONLY. What reaches the screen is the GPU's: far out on double, ordinary
## meshes are steady and billboards still step on float32's grid (2026-09-14, `tests/shake_shot.gd`,
## and agents.md, "What the double build does and does not steady").
##
## A MEASUREMENT, NOT A SUITE. It has nothing to pass or fail -- the numbers are a property
## of the float format and will not change until the world is drawn nearer the origin -- so
## it is deliberately not in `run_all.ps1`. Run it by hand:
##
##   Godot --headless --path cockpit res://tests/jitter.tscn

const EYE := Vector3(0.24, 0.94, -0.34)


func _ready() -> void:
	print("[jitter] the grid a cockpit control is drawn on, by distance from the origin")
	print("[jitter] %12s %14s %16s" % ["distance", "step", "at arm's length"])
	for out_there in [0.0, 500.0, 2000.0, 7200.0, 9460.0, 16000.0]:
		print("[jitter] %9.0f m %11.4f mm %13.2f arcmin" % [
			out_there, _grid_at(out_there) * 1000.0,
			rad_to_deg(_grid_at(out_there) / 0.5) * 60.0])
	print("[jitter] the carrier sits 9460 m out; human vernier acuity is about 0.5 arcmin")
	get_tree().quit()


## THE SMALLEST CHANGE THAT SURVIVES. A craft at `out_there` metres, an instrument in front
## of the pilot, and the craft crept forward by less and less until the drawn position of
## that instrument stops changing at all. What is left is the grid.
func _grid_at(out_there: float) -> float:
	var craft := Transform3D(Basis.IDENTITY, Vector3(out_there * 0.7, 500.0, out_there * 0.7))
	var was: Vector3 = (craft * Transform3D(Basis.IDENTITY, EYE)).origin
	var creep: float = 1.0
	for i in range(40):
		var moved := Transform3D(craft.basis, craft.origin + Vector3(creep, 0.0, 0.0))
		if (moved * Transform3D(Basis.IDENTITY, EYE)).origin == was:
			return creep * 2.0
		creep *= 0.5
	return creep
