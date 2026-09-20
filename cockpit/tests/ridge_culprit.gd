extends Node
## Headless, and NOT A SUITE: which range puts rock into a place something else objects to?
##
##   Godot --headless --path cockpit res://tests/ridge_culprit.tscn
##
## `tests/airport.gd` reports the worst point on a glide path as "so far out, so far across", in the runway's own frame,
## which is the right thing for it to say and the wrong thing to act on: it names a place but not a RANGE. This walks
## the same finals the same way, finds the worst point, and then asks every range of `MountainRanges` ON ITS OWN how
## high it stands there -- so the answer is a salt, not a coordinate.
##
## Written after three goes at this by reasoning about compass bearings, each of which moved the wrong arc and cost a
## twenty-second suite run to find out (2026-09-19). Guessing which arc is over a place is not cheaper than asking.

func _ready() -> void:
	var rock: Object = Terrain.mountains()
	if rock == null:
		print("RESULT=FAIL no mountains")
		get_tree().quit(1)
		return
	for field in Airfield.here():
		_worst_on(field, rock)
	print("RESULT=PASS")
	get_tree().quit(0)


## THE WORST POINT ON ONE FIELD'S FINAL, walked exactly as `tests/airport.gd` walks it, and what is under it.
func _worst_on(field: Dictionary, rock: Object) -> void:
	var p: TrafficPattern = Airfield.pattern_for(field, Sim.Kind.JUMBO)
	var ifr := InstrumentApproach.make(p, Airfield.numbers_of(Sim.Kind.JUMBO))
	var worst: float = INF
	var worst_at := Vector3.ZERO
	var worst_says := ""
	var out: float = 0.0
	while out <= ifr.established_out():
		var across: float = -600.0
		while across <= 600.0:
			var at: Vector3 = p.point(-out, across)
			var clear: float = ifr.final_height(at) - p.field - float(rock.call("surface_at", at.x, at.z))
			if clear < worst:
				worst = clear
				worst_at = at
				worst_says = "%.0f m out, %.0f m across" % [out, across]
			across += 50.0
		out += 100.0
	print("[culprit] %s: least %.0f m at %s -- world (%.0f, %.0f), %.0f m from the middle, bearing %.1f" % [
		field["id"], worst, worst_says, worst_at.x, worst_at.z, Vector2(worst_at.x, worst_at.z).length(),
		fposmod(rad_to_deg(atan2(worst_at.z, worst_at.x)), 360.0)])
	# AND THE WORST POINT THAT HAS ROCK UNDER IT, which is a different question and usually a different place. The
	# smallest clearance on a final is normally over the THRESHOLD, where the aeroplane is lowest and there is no rock
	# at all by construction -- so quoting that number as a terrain margin reads a fixed piece of approach geometry as
	# a lucky escape (pilotcost and ridges, 2026-09-19).
	var over_rock: float = INF
	var over_rock_says := ""
	var over_rock_at := Vector3.ZERO
	out = 0.0
	while out <= ifr.established_out():
		var across: float = -600.0
		while across <= 600.0:
			var at: Vector3 = p.point(-out, across)
			var stands: float = float(rock.call("surface_at", at.x, at.z))
			if stands > 1.0:
				var clear: float = ifr.final_height(at) - p.field - stands
				if clear < over_rock:
					over_rock = clear
					over_rock_at = at
					over_rock_says = "%.0f m out, %.0f m across, over %.0f m of rock" % [out, across, stands]
			across += 50.0
		out += 100.0
	if is_inf(over_rock):
		print("[culprit]   no rock stands anywhere under this final")
	else:
		print("[culprit]   least OVER ROCK %.0f m at %s -- world (%.0f, %.0f)" % [over_rock, over_rock_says,
			over_rock_at.x, over_rock_at.z])
	# AND WHOSE ROCK IT IS: every range built alone, so the one standing there is named by its salt.
	var blamed: Array[String] = []
	for one in MountainRanges.ranges():
		var alone: Object = ClassDB.instantiate(&"MountainRange")
		alone.call("configure", {"spacing": MountainRanges.SPACING, "tile_quads": MountainRanges.TILE_QUADS,
			"ranges": [one], "keepouts": PackedInt32Array()})
		var stands: float = float(alone.call("surface_at", worst_at.x, worst_at.z))
		if stands > 1.0:
			blamed.append("salt %d stands %.0f m (peak %d, saddle %d)" % [int(one["salt"]), stands, int(one["peak"]),
				int(one["saddle"])])
	print("[culprit]   under it: %s" % ["nothing" if blamed.is_empty() else ", ".join(blamed)])
