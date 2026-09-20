extends MultiMeshInstance3D
class_name TowerPlume
## THE STEAM OFF A COOLING TOWER: puffs that climb out of the lip, spread, lean downwind and go out.
##
## WHAT IT IS AND IS NOT. This is condensed water vapour, not smoke. It leaves the lip at about the
## diameter of the lip, climbs faster than a hillside fire's column because it is buoyant and pushed by
## the draught, spreads as it goes, and disappears rather than thinning away to a stain -- a plume has an
## END, at the height where the vapour has mixed enough to stop condensing, and drawing one that fades
## for ever reads as smog. So `CLIMBS` is a height the plume stops at, not a fade.
##
## IT REUSES `wisp.gdshader` AND WRITES NO SHADER OF ITS OWN. That shader was written for the wisps in a
## thermal (`world/lift_yard.gd`) and it is already the right thing: unshaded, mix-blended, two-sided, no
## depth write, alpha thinning towards the silhouette so a sphere does not read as a pale ellipse with a
## hard rim, and the bottom of each puff faded out. It already includes the mist, which every see-through
## shader in this project must (`tests/lint.gd:and_every_see_through_shader_is_misted_or_says_why_not`),
## and it already hands the mist its own clock rather than TIME. A second shader that did the same things
## would be a second place for those four rules to be got wrong.
##
## ONE MULTIMESH FOR THE WHOLE PLUME, spheres with per-instance colour, which is `LiftYard`'s arrangement
## for the same reason: the only thing that changes per frame is a transform and an alpha, and rewriting a
## MultiMesh buffer is the cheap way to move twenty things.
##
## `puff_at` IS STATIC AND PURE, so the suite can ask what the plume drew without a rendering server. A
## MultiMesh read back headless answers a default for every instance, so a check that asks the buffer is
## asking the dummy driver (`world/lift_yard.gd` says so in as many words, and it is the same trap).
##
## THE PUFFS CLIMB AND ARE RECYCLED rather than sitting still and wobbling, which is `FireYard`'s fine
## finish and the difference between a column and a string of beads: each puff is given a phase, climbs
## from 0 to 1 over `RISE_SECONDS`, and starts again at the lip. Twenty-four of them keep the gaps closed
## at the bottom, where they are smallest and furthest apart in angle.
##
## AND THERE IS NO WARM-UP: THE PLUME IS WHOLE ON THE FIRST FRAME IT IS DRAWN. A puff's phase is
## `index / PUFFS` plus the clock, so at `t = 0` the twenty-four of them are already spread evenly up the
## whole column. This is not a particle system and nothing is emitted: `puff_at` is a pure function of the
## clock, and the plume at `t = 0` is the same plume as at any other moment.
##
## THAT MATTERS TO A PROBE RATHER THAN TO A PLAYER. `lane/buildings` is photographing every building in
## the game, and a particle plume needs frames to develop -- a gallery that screenshots on frame one gets
## an empty sky over the tower and no error. **This one needs zero.** It is held by
## `tests/cooling_towers.gd:the_plume_is_whole_on_the_frame_it_is_first_drawn`, so a later change that
## turns it into something that does need a warm-up cannot do so quietly.
##
## THE LEAN IS THE SAME ARITHMETIC AS THE FIRES', taken from the same authority. `Terrain.WIND` is what
## `Sky` hands `FireYard.set_drift`, and a plume that leaned on a different wind from the smoke two
## valleys away would be the one thing in the picture saying the weather is not a weather.

## THE SHADER, and it belongs to the wisps. Reused, never edited from here.
const WISP: Shader = preload("res://world/shaders/wisp.gdshader")

## How many puffs make a plume. Below about sixteen the bottom of the column shows gaps between them,
## because that is where they are smallest and furthest apart in angle (`FireYard.PUFFS`, same reason).
const PUFFS: int = 24
## HOW FAR THE PLUME CLIMBS, in tower heights. Asked of the tower rather than typed in metres, so a change
## to the model cannot leave the steam standing beside it: at the tower's 99.2 m this is 179 m.
## ESTIMATE. A real plume's height is weather -- it is a few tower heights on a cold damp morning and
## almost nothing on a warm dry afternoon -- and nothing here models the air's humidity, so one height is
## drawn and the number is a plausible one rather than a measurement.
##
## IT WAS 3.0 UNTIL SOMEBODY LOOKED AT IT. Three hundred metres of plume over a 99 m tower photographed as a
## thin white ROPE going straight up -- a chimney's smoke, not a cooling tower's steam -- because the same
## puffs spread over three times the height are three times as far apart and the column loses its bulk. The
## picture is screenshots/2026-09-17/cockpit-cooling-02-plume-a-rope-and-one-tower-hiding-the-other.png; no check moved.
const CLIMBS: float = 1.8
## HOW LONG A PUFF TAKES TO CLIMB THE WHOLE PLUME, seconds -- and the number it is set against is the one
## piece of tuning in this project that has already decided where the line between smoke and steam is.
## `FireYard.RISE_SECONDS` is 38 s, with the comment "slow enough to read as smoke rather than steam".
## This wants the other side of that line, and can say by how much.
##
## BUT THE TWO DURATIONS ARE NOT COMPARABLE AND COMPARING THEM WOULD HAVE BEEN WRONG. 38 s is for
## `FireYard.COLUMN_HEIGHT`'s 260 m; this plume is 179 m. A duration is a height divided by a rate, so two
## durations for two different heights say nothing. **The comparable quantity is the RATE**: the fire's
## column climbs at 260 / 38 = 6.8 m/s, which is the speed somebody decided reads as smoke.
##
## At the 22 s this was first written with, this plume climbed at 179 / 22 = 8.1 m/s -- nineteen per cent
## faster, which is not "visibly" anything. At 12 s it climbs at 14.9 m/s, **2.2 times the speed that was
## tuned to read as smoke**, which is a difference a viewer can see rather than one a spreadsheet can.
##
## `tests/cooling_towers.gd:the_steam_climbs_faster_than_the_rate_tuned_to_read_as_smoke` holds it as a
## rate against `FireYard`'s own two constants, so nobody can move either side of it in isolation.
const RISE_SECONDS: float = 12.0
## How wide a puff is at the lip and at the top, as a share of the lip's own radius. A plume leaves at
## about the diameter it left through and roughly triples across its visible height.
const WIDE_AT_LIP: float = 1.05
const WIDE_AT_TOP: float = 2.8
## Where in its climb a puff is at full strength, and the alpha it reaches. It fades in over the first
## stretch -- vapour takes a moment to condense above the lip -- and out over the last, which is where a
## plume ends.
## THESE WERE 0.22 / 0.62 / 0.85 AND THE PLUME PHOTOGRAPHED AS A CLUB OF COTTON WOOL: a solid white bulb
## with a hard dome on top, because twenty-four puffs at 0.85 alpha over a shorter column overlap into
## something opaque. Steam is SEEN THROUGH -- the sky shows through a plume's edges and often through its
## middle. screenshots/2026-09-17/cockpit-cooling-03-the-plume-as-a-club-of-cotton-wool.png is the club.
const FULL_AT: float = 0.18
const FADES_FROM: float = 0.45
const STRONGEST: float = 0.5
## How much one puff differs from the next in strength. A column of identical puffs reads as one object;
## the variation is taken from the index rather than from a random, so every peer draws the same plume.
const UNEVEN: float = 0.3
## Metres of lean per metre of climb, per metre a second of wind. `FireYard.set_drift`'s number, so a
## plume and a fire two valleys apart lean the same way in the same wind.
const LEAN_PER_WIND: float = 0.09
## Pale, and a little blue: condensate is whiter than smoke and takes the sky's colour at its edges.
const STEAM: Color = Color(0.93, 0.95, 0.98, 0.32)

## How high the lip this plume stands on is, and how wide, in metres. Written by `stand_on`.
var lip_height: float = 0.0
var lip_radius: float = 1.0
## Metres of lean per metre of climb, from the wind. See `set_drift`.
var drift: Vector3 = Vector3.ZERO

var _clock: float = 0.0


## THE PLUME ON A TOWER'S LIP. `radius` is the lip's own radius and `height` how far above this node's
## origin it is, so a plume added as a child of a tower at the tower's own origin lands on its lip.
func stand_on(height: float, radius: float) -> void:
	lip_height = height
	lip_radius = radius
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	# LOW POLY, like everything else here, and a puff is a blob behind a rim fade: at the distance a plume
	# is read from, eight rings of twelve is already more than the silhouette can show.
	ball.radial_segments = 12
	ball.rings = 6
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = ball
	batch.instance_count = PUFFS
	multimesh = batch
	var paint := ShaderMaterial.new()
	paint.shader = WISP
	paint.set_shader_parameter("tint", Vector4(STEAM.r, STEAM.g, STEAM.b, STEAM.a))
	material_override = paint
	# NEVER CULLED BY ITS OWN BOX. The plume is three hundred metres of thin spheres over a tower, and the
	# thing a pilot picks a power station out by from ten kilometres is the steam, not the concrete.
	custom_aabb = AABB(Vector3(-lip_radius * 4.0, 0.0, -lip_radius * 4.0),
		Vector3(lip_radius * 8.0, lip_height + climb(), lip_radius * 8.0))
	_write()


## HOW THE PLUME LEANS: straight off the wind, the same arithmetic `FireYard.set_drift` uses.
func set_drift(wind: Vector3) -> void:
	drift = wind * LEAN_PER_WIND


## HOW FAR THIS PLUME CLIMBS, metres. One number, one place: `CLIMBS` tower heights.
func climb() -> float:
	return CoolingTower.overall_height() * CLIMBS


func _process(delta: float) -> void:
	_clock += delta
	_write()


func _write() -> void:
	if multimesh == null:
		return
	for i in range(PUFFS):
		var puff: Dictionary = puff_at(i, _clock, lip_height, lip_radius, climb(), drift)
		multimesh.set_instance_transform(i, puff["transform"])
		multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, float(puff["alpha"])))


## ONE PUFF, STATIC AND PURE, so a suite can ask where it is without a rendering server. `at` is seconds
## since the plume started; every other argument is the plume's own geometry. Returns
## `{"transform", "alpha", "climbed"}`, where `climbed` is 0 at the lip and 1 at the top.
static func puff_at(index: int, at: float, lip: float, radius: float, height: float,
		lean: Vector3) -> Dictionary:
	var phase: float = fposmod(at / RISE_SECONDS + float(index) / float(PUFFS), 1.0)
	var risen: float = phase * height
	# A LITTLE OFF THE AXIS, and each puff a different amount, so the column is a column and not a skewer.
	# Taken from the index, not from a random, so every peer draws the same plume without sending anything.
	var angle: float = float(index) * TAU * 0.61803398875
	var wander: float = radius * 0.35 * (0.3 + phase)
	# WIDENS FAST AND THEN SLOWLY, which is what a plume does: it spreads hardest just above the lip where
	# it is still being pushed out, and drifts after that. Straight in `phase` drew a cone.
	var across: float = lerpf(WIDE_AT_LIP, WIDE_AT_TOP, sqrt(phase)) * radius * 2.0
	var middle := Vector3(cos(angle) * wander, lip + risen, sin(angle) * wander) + lean * risen
	var placed := Transform3D(Basis.IDENTITY.scaled(Vector3(across, across, across)), middle)
	var uneven: float = 1.0 - UNEVEN * fposmod(float(index) * 0.7548776662, 1.0)
	return {"transform": placed, "alpha": alpha_at(phase) * uneven, "climbed": phase}


## HOW STRONG A PUFF IS AT `phase` of its climb: fading in above the lip, full through the middle, gone by
## the top. Exported so the suite can hold the shape of the plume without reading the MultiMesh.
static func alpha_at(phase: float) -> float:
	var rising: float = smoothstep(0.0, FULL_AT, phase)
	var going: float = 1.0 - smoothstep(FADES_FROM, 1.0, phase)
	return STRONGEST * rising * going
