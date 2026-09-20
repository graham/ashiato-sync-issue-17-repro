extends Node
## Headless and pure: does the clock put the sun where the three old presets had it, and is the look at each preset's point
## on the clock that preset, key for key -- and between them, does the look change a little at a time?
##
##   tools\gate_run.ps1 -Suite daytime
##
## THE CLOCK (2026-09-18, `Orrery`, `DaylightTuning.look_at`). "The three presets must look as they do now", from team-lead's
## brief, is two claims: the SUN stands where it stood, and every NUMBER the world is lit by is the preset's. The first is
## held here to the old suns written down as numbers -- DAY 34.8 up at azimuth 30.6, EVENING 7.0 up at 250.0, both read
## off `DaylightTuning` as it was before the clock -- never to anything `Orrery` works out, so a sky solved wrong goes red.
## The second is held against the presets themselves, which are still the one place those numbers are written. What the
## world looks like at those points is in the before and after pictures (godotgames-drafts/2026-09-18/cockpit-daytime).
##
## Read RESULT=, not the exit code.

## THE OLD SUNS, as `DaylightTuning` placed them until 2026-09-18: elevation, and azimuth round from +Z towards +X.
const DAY_SUN_WAS := Vector2(34.8, 30.6)
const EVENING_SUN_WAS := Vector2(7.0, 250.0)
## How close is the same sun, degrees: a twentieth of the sun's own width.
const SAME_SUN: float = 0.05
## HOW MUCH A LOOK MAY CHANGE IN ONE MINUTE OF THE CLOCK, as a share of the whole range the key has over the day: a 24-hour
## walk minute by minute that jumps more than this anywhere is a snap between looks, not a blend. A minute is a
## four-hundred-and-fortieth of the day, and the steepest real change -- the light going out as the sun sets, over the six
## degrees from `SUN_FULL` to `SUN_GONE`, about 35 minutes -- moves under a twentieth of the range a minute.
const MOST_A_MINUTE: float = 0.08

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[daytime] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_clock_puts_the_sun_where_day_and_evening_had_it()
	_the_look_at_each_presets_point_is_that_preset()
	_the_look_changes_a_little_every_minute_round_the_clock()
	_the_lamps_come_on_once_as_the_sun_goes_down_and_do_not_flicker()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


static func _towards(elevation: float, azimuth: float) -> Vector3:
	var up: float = deg_to_rad(elevation)
	var round_from_z: float = deg_to_rad(azimuth)
	return Vector3(cos(up) * sin(round_from_z), sin(up), cos(up) * cos(round_from_z))


## DAY AND EVENING'S SUNS ARE WHERE THEY WERE, at the clock's DAY and EVENING -- and those are morning and evening.
func _the_clock_puts_the_sun_where_day_and_evening_had_it() -> void:
	var day_at: float = DaylightTuning.clock_of(DaylightTuning.When.DAY)
	var evening_at: float = DaylightTuning.clock_of(DaylightTuning.When.EVENING)
	var day_off: float = rad_to_deg(Orrery.sun(day_at).angle_to(_towards(DAY_SUN_WAS.x, DAY_SUN_WAS.y)))
	var evening_off: float = rad_to_deg(Orrery.sun(evening_at).angle_to(_towards(EVENING_SUN_WAS.x, EVENING_SUN_WAS.y)))
	_check("the_clock_puts_the_sun_where_day_and_evening_had_it",
		day_off < SAME_SUN and evening_off < SAME_SUN and day_at < 780.0 and evening_at > 780.0,
		"DAY at %s, %.4f degrees off; EVENING at %s, %.4f degrees off" % [Orrery.words(day_at), day_off,
			Orrery.words(evening_at), evening_off])


## THE LOOK AT DAY, EVENING AND NIGHT IS THE PRESET, every key the preset has that the world is lit by.
func _the_look_at_each_presets_point_is_that_preset() -> void:
	var wrong: PackedStringArray = []
	for which in DaylightTuning.When.values():
		var preset: Dictionary = DaylightTuning.preset(which)
		var look: Dictionary = DaylightTuning.look_of(which)
		for key in preset.keys():
			if key in DaylightTuning.NOT_BLENDED:
				continue
			if not _same(preset[key], look.get(key)):
				wrong.append("%s %s: %s, preset %s" % [DaylightTuning.name_of(which), key, look.get(key), preset[key]])
	_check("the_look_at_each_presets_point_is_that_preset", wrong.is_empty(),
		"%d keys differ%s" % [wrong.size(), "" if wrong.is_empty() else ": " + "; ".join(wrong.slice(0, 4))])


static func _same(a: Variant, b: Variant) -> bool:
	if a is Color and b is Color:
		return (a as Color).is_equal_approx(b)
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.000001
	return a == b


## AND BETWEEN THEM A LITTLE AT A TIME: every number and colour a look has, walked round the clock a minute at a time, never
## jumps by more than `MOST_A_MINUTE` of its own range over the day. A look that snapped between presets would move the
## whole range in one minute.
func _the_look_changes_a_little_every_minute_round_the_clock() -> void:
	var walk: Array[Dictionary] = []
	for minute in range(int(Orrery.DAY_LONG) + 1):
		walk.append(DaylightTuning.look_at(float(minute)))
	var worst_key: String = ""
	var worst: float = 0.0
	var at: float = 0.0
	for key in DaylightTuning.DAY.keys():
		if key in DaylightTuning.NOT_BLENDED:
			continue
		var values: Array = []
		for look in walk:
			# THE LIGHT'S COLOUR COUNTS BY ITS ENERGY: it turns from the sun's to the moon's where the light is dark.
			values.append(_as_number(look[key]) * (float(look["sun_energy"]) if key == "sun_colour" else 1.0))
		var low: float = values.min()
		var high: float = values.max()
		if high - low <= 0.0:
			continue
		for i in range(1, values.size()):
			var jump: float = absf(float(values[i]) - float(values[i - 1])) / (high - low)
			if jump > worst:
				worst = jump
				worst_key = key
				at = float(i)
	_check("the_look_changes_a_little_every_minute_round_the_clock", worst <= MOST_A_MINUTE,
		"the most any key moves in a minute is %.3f of its range (%s at %s), allowed %.2f" % [worst, worst_key,
			Orrery.words(at), MOST_A_MINUTE])


## THE LAMPS COME ON ONCE AS THE SUN GOES DOWN, AND A SUN HOVERING AT THE THRESHOLD DOES NOT FLICKER THEM. Off at DAY, on at
## EVENING, as the presets had them; and walked back and forth across `Daylight.LAMPS_ON_BELOW` by a minute at a time -- the
## sun a few hundredths of a degree either side of it -- they change once. A `Daylight` with no light and no air, so only
## its own decision is asked.
func _the_lamps_come_on_once_as_the_sun_goes_down_and_do_not_flicker() -> void:
	var daylight := Daylight.new(null, null)
	daylight.show_time(DaylightTuning.When.DAY)
	var by_day: bool = daylight.lamps
	var threshold: float = Orrery.when_the_sun_is(Daylight.LAMPS_ON_BELOW, false)
	var changes: int = 0
	var was: bool = daylight.lamps
	for i in range(20):
		daylight.show_clock(threshold + (1.0 if i % 2 == 0 else -1.0))
		if daylight.lamps != was:
			changes += 1
			was = daylight.lamps
	daylight.show_time(DaylightTuning.When.EVENING)
	var at_evening: bool = daylight.lamps
	daylight.free()
	_check("the_lamps_come_on_once_as_the_sun_goes_down_and_do_not_flicker",
		not by_day and at_evening and changes == 1,
		"by day %s, at evening %s, %d changes over 20 minutes either side of %s" % [by_day, at_evening, changes,
			Orrery.words(threshold)])


## A value as one number to walk: a colour by the sum of its channels, a vector by its length.
static func _as_number(value: Variant) -> float:
	if value is Color:
		return (value as Color).r + (value as Color).g + (value as Color).b
	if value is Vector2 or value is Vector3:
		return value.length()
	if value is bool:
		return 1.0 if value else 0.0
	return float(value)
