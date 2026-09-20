extends RefCounted
## EVERY NUMBER ABOUT A TREE, ON BOTH FINISHES, AND THE ONE PLACE ANY OF THEM IS WRITTEN.
##
## The user asked for detail controls to make the fine forest look convincing, and for
## performance to matter. So the knobs are here, all of them, as two tables side by side --
## PLAIN and FINE -- and nothing that plants, meshes or shades a tree has a number of its own:
## `world/woodland.gd` reads these, and the forest shaders declare every uniform with no
## initialiser, so a value that is not set from here is not set at all. `tests/forest.gd` changes
## each key in turn and fails if the wood does not change with it, which is what catches the copy
## somebody typed into a shader "just for now".
##
## THE DECISION: A TABLE PER FINISH, NOT A SLIDER. What a player can decide in a headset is "this
## is too slow" (see `autoload/finish.gd`); what a person tuning the forest wants is every number
## in one file with its reason beside it, and a probe flag to try one without editing it:
## `--forest=trees_per_hectare=90,fade_to=2400` on `tests/scenery_shot.gd`.
##
## NOT A CLASS NAME, preloaded by path like `world/stopwatch.gd`: a name in the global class cache
## is one more thing a fresh checkout has to import before anything that mentions it parses.
##
## IF A COST LIMIT IS MISSED, THESE COME DOWN FIRST -- density, the fade distances, then the chunk
## size -- before anything structural changes.

## THE PLAIN FOREST: the cheapest thing that reads as a wood from a cockpit.
const PLAIN: Dictionary = {
	# HOW MANY TREES, before a stand's own density. A hectare is 100 x 100 m. PLAIN's trees are a
	# subset of FINE's lattice (see `woodland.gd`), so this must not exceed FINE's. 70 until 2026-09-13,
	# when the user found "The forrest is too dense": 45, and FINE 160 to 100.
	"trees_per_hectare": 45.0,
	# How far a tree wanders off its lattice point, as a share of the lattice spacing, either way
	# half of it. Under 1, so no two neighbours can land in the same place.
	"jitter": 0.9,
	# THE CHUNK: one MultiMeshInstance3D, one draw call, per this many metres of stand, laid in the
	# stand's own frame. A MultiMesh is culled as one box, so a wood drawn as one mesh is all in or
	# all out; 128 m keeps the two starting stands to 68 draws where the whole wood is in view.
	"chunk": 128.0,
	# THE FAR FADE, in metres from the eye: every tree whole out to `fade_from`, every tree gone by
	# `fade_to`, each one shrinking to nothing over its own slice of the band (see the shader).
	"fade_from": 1800.0,
	"fade_to": 2600.0,
	# THE NEAR RING: within `near_range` every lattice tree this finish has is drawn; past it, only
	# `far_share` of them. PLAIN draws the same density everywhere.
	"near_range": 0.0,
	"far_share": 1.0,
	# A TREE'S SIZE, in metres to the top, from the instance hash.
	"height_min": 10.0,
	"height_max": 22.0,
	# How wide the crown is, as a fraction of the tree's height, for each kind.
	"conifer_width": 0.30,
	"broadleaf_width": 0.55,
	# How much of the tree is bare trunk below the crown, as a fraction of its height, and how thick
	# the trunk is, as a diameter against the height.
	"trunk_share": 0.22,
	"trunk_width": 0.05,
	# THE MESH: how many tiers a crown is built from, how many sides each crown ring has, and how many
	# the trunk has. PLAIN is one crown of six sides on a three-sided trunk. A crown tier is a point
	# below, two rings and a point above, four triangles a side: 3 x 2 + 6 x 4 = 30 triangles.
	"crown_tiers": 1.0,
	"crown_sides": 6.0,
	"trunk_sides": 3.0,
	# COLOUR. The crown of a conifer and of a broadleaf at their darkest and lightest; every tree's
	# own tint is a hash between the two. sRGB, like every colour in sky.tscn: the shaders take them
	# as `source_color`.
	"conifer_dark": Color(0.06, 0.13, 0.07),
	"conifer_light": Color(0.11, 0.21, 0.10),
	"broadleaf_dark": Color(0.10, 0.19, 0.07),
	"broadleaf_light": Color(0.20, 0.30, 0.11),
	"trunk_colour": Color(0.17, 0.13, 0.09),
	# THE GROUND UNDER A WOOD, drawn by the grass shader: the forest floor's colour and how far the
	# field is pulled towards it. It is also the wood's shadow, since the trees cast none.
	"floor_colour": Color(0.07, 0.11, 0.05),
	"floor_strength": 0.75,
	# THE EDGE OF A WOOD THINS OUT, asked for by the user ("dither the amount of trees near the edge so
	# that the falloff makes it a bit smoother"). Within `edge_band` metres of a side a tree is kept
	# with a chance that rises from 0 at the side to 1 at the band's inner edge, as that share raised
	# to `edge_curve`; the band's width wanders along each side by up to `edge_wander` of itself, so
	# its inner edge is not a second rectangle; and a tree in it is up to `edge_shrink` shorter. The
	# forest floor's edge follows the same band and curve. Not zero: a hard edge crawls in a headset.
	# TWICE AS WIDE AND FALLING AS THE SQUARE from 2026-09-13 (60 m and 1.5 before): "more dithering near
	# the edges (less trees so it blends into the 'non forrest')". The last trees stand as singles and
	# clumps -- see `edge_clumps` in FINE's table, which both finishes read.
	"edge_band": 120.0,
	"edge_curve": 2.0,
	"edge_wander": 0.5,
	"edge_shrink": 0.25,
	# THE MOST STANDS THE GROUND CAN PAINT A FLOOR UNDER: the length of the arrays in
	# `forest_floor.gdshaderinc`, which a shader cannot take from a uniform. A test holds the two
	# together, and a catalogue with more stands than this warns and grows the rest with no floor.
	"most_stands": 8.0,
	# No lean on PLAIN. And NO WIND AT ALL: the plain shader has none, so `sway` and `sway_rate` are
	# not in this table -- a number here that nothing reads would be a detail control that does nothing.
	"lean_max": 0.0,
}

## THE FINE FOREST: more, taller-looking, lit, and moving -- measured against PLAIN in agents.md.
const FINE: Dictionary = {
	"trees_per_hectare": 100.0,
	"jitter": 0.9,
	"chunk": 128.0,
	"fade_from": 2400.0,
	"fade_to": 3600.0,
	# Denser near the eye, thinner far off, in the vertex shader rather than in more chunks: see the
	# note on `chunk` above, and agents.md for why 64 m cells were rejected.
	"near_range": 500.0,
	"far_share": 0.5,
	"height_min": 9.0,
	"height_max": 26.0,
	"conifer_width": 0.30,
	"broadleaf_width": 0.60,
	"trunk_share": 0.20,
	"trunk_width": 0.05,
	# THREE TIERS OF CROWN on eight sides, and a four-sided trunk: 4 x 2 + 3 x 8 x 4 = 104 triangles.
	"crown_tiers": 3.0,
	"crown_sides": 8.0,
	"trunk_sides": 4.0,
	"conifer_dark": Color(0.05, 0.12, 0.06),
	"conifer_light": Color(0.12, 0.23, 0.11),
	"broadleaf_dark": Color(0.09, 0.18, 0.06),
	"broadleaf_light": Color(0.23, 0.33, 0.12),
	"trunk_colour": Color(0.17, 0.13, 0.09),
	"floor_colour": Color(0.06, 0.10, 0.05),
	"floor_strength": 0.80,
	"edge_band": 140.0,
	"edge_curve": 2.0,
	"edge_wander": 0.5,
	"edge_shrink": 0.3,
	# PATCHES IN THE MIDDLE, NOT GLADES. A slow noise over the stand keeps between `patch_least` and all of
	# the trees, so a wood seen from the air is thicker and thinner in places; never less than
	# `patch_least`, so there is never a hole -- "less dense", asked for, and not bare clearings (team-lead,
	# 2026-09-13). `patch_scale` is a patch's size in metres. FINE's table only: both finishes read these
	# off the lattice, because a noise read on each finish's own numbers is the subset bug the edge's
	# wander was (see `woodland.gd`).
	"patch_scale": 110.0,
	"patch_least": 0.6,
	# CLUMPS AT THE EDGE. Inside the band a finer noise decides which trees survive, so the last ones stand
	# as singles and small clumps rather than an even dust. `edge_clumps` is how far it decides (0 an even
	# thinning, 1 all noise) at the band's outer side, fading to nothing at its inner edge; `clump_scale`
	# is a clump's size in metres. Also read off the lattice on both finishes.
	"edge_clumps": 0.6,
	"clump_scale": 35.0,
	"most_stands": 8.0,
	# FINE ONLY: how far, in metres, the floor's edge wanders out past the thinning trees on a slow noise.
	# 22 m until the band doubled on 2026-09-13.
	"floor_ragged": 40.0,
	# Radians a tree may lean, from its hash.
	"lean_max": 0.07,
	# How far the top of a tree moves in the wind, in metres, and how fast it swings, in radians a
	# second. Whole-tree bend only: leaf motion is invisible from a cockpit.
	"sway": 0.35,
	"sway_rate": 1.1,
}


## ONE FINISH'S NUMBERS, as a copy anybody may write to, with `overrides` on top.
##
## An override for a key neither table has is refused with a warning rather than quietly added: a
## misspelt `--forest=fade=900` doing nothing would send somebody looking for a bug in the fade. One
## the other finish has and this one does not (`sway` on PLAIN) is simply not this finish's.
static func for_tier(fine: bool, overrides: Dictionary) -> Dictionary:
	var out: Dictionary = (FINE if fine else PLAIN).duplicate()
	var other: Dictionary = PLAIN if fine else FINE
	for key in overrides:
		if out.has(key):
			out[key] = overrides[key]
		elif not other.has(key):
			push_warning("[forest] no tuning called %s; the keys are %s" % [key, ", ".join(FINE.keys())])
	return out


## `--forest=off`: no woods at all, and no forest floor -- for timing a build with the forests against
## the same build without them.
static func switched_off() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.lstrip("-") == "forest=off":
			return true
	return false


## `--forest=key=value,key=value` off the command line, as overrides. Numbers only: colours are
## edited here, in the file, where they can be seen.
static func asked_on_the_command_line() -> Dictionary:
	var out: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		var bare: String = argument.lstrip("-")
		if not bare.begins_with("forest=") or bare == "forest=off":
			continue
		for pair in bare.substr("forest=".length()).split(",", false):
			var parts: PackedStringArray = pair.split("=")
			if parts.size() != 2 or not parts[1].is_valid_float():
				push_warning("[forest] --forest=%s is not key=number" % pair)
				continue
			out[parts[0]] = float(parts[1])
	return out
