@tool
extends DetentDial
class_name TimeOfDayDial
## A SELECTOR FOR THE TIME OF DAY: DAY, EVENING and NIGHT, on the panel where a hand can find it.
##
## Asked for on 2026-09-13: "make me a detent knob switch to move between day, evening, night so i can add it to the
## plane". The builder places it like any other part; no cockpit is built with one.
##
## A CLASS, AND NOT A DETENT DIAL WITH OTHER WORDS ON IT, and the reason is the file. A part is named by its script
## (`ControlCatalogue.part_of`), and a saved layout brings back a part's channel, range and scope but not its stops -- so
## a DetentDial relabelled DAY, EVENING, NIGHT would come back from SAVE as LOW, MED, HIGH on the craft's MODE channel. A
## second table of "configured parts" beside the class names was the other way, and two tables for one question is how
## the mount rule came to have three versions.
##
## IT ASKS, AND IS TOLD. Turning it announces `chose_time`; the level decides with `FlightLevel.choose_time`, the call the
## board's TIME tab lands on, and every change comes back through `PilotRig.show_time` to `show_time` here -- so NIGHT
## pressed on the board turns this knob, and nothing here keeps a time of its own. Under a hand it moves with the wrist,
## because a detent that does not click under you is no detent; let go, and it shows what the level has on.
##
## THE PILOT'S (`Scope.PILOT`) AND ON NO CHANNEL: never sent and never drawn from anybody else's, which is what the TIME
## tab promises -- nobody else's sky changes. The words are `DaylightTuning.When`'s, so a fourth time there is a fourth
## stop here.
##
## IN THE HALL IT IS SILENT. There is no level and no sky, so nothing listens to `chose_time` and nothing is shown: it
## turns and stays where it is left. agents.md, WHAT IS NOT HERE YET.

## The wrist turned it onto another stop. `time` is a `DaylightTuning.When`.
signal chose_time(time: int)

## WHICH OF ITS STOPS THE LEVEL'S CLOCK IS NEAREST, or -1 where there is no sky. What this knob shows, as `ClipboardPage`
## keeps `_time_shown` for its highlight -- not a second copy of the time.
##
## THREE STOPS ON A CLOCK (2026-09-18). The time of day is any minute now, and the knob follows it to the preset it is
## nearest (`Daylight.nearest_preset`), so it turns on its own through the evening as the clock runs; turning it sets that
## preset's point on the clock. NOT FIVE STOPS, with DAWN and DUSK: the three names already needed the placard moved back
## a centimetre so EVENING and NIGHT did not run together from the seat (DetentDial's LEGEND_BACK), and five on the same
## sweep would crowd again. Any other time is the board's.
var _time_shown: int = -1


func label_text() -> String:
	return "DIAL\nTIME OF DAY"


func _build() -> void:
	stops = PackedStringArray(DaylightTuning.When.keys())
	super._build()
	control_name = "time of day"
	scope = Scope.PILOT
	# NO CHANNEL. `DetentDial._build` wires an unwired dial to MODE; the time of day is not on the bus at all.
	channel = -1


## THE CLOCK THE LEVEL HAS ON, minutes, handed in on every step; the knob goes to the stop it is nearest. Refused while a
## hand holds it, as any `apply` is.
func show_time(minutes: float) -> void:
	_time_shown = Daylight.nearest_preset(minutes) if minutes >= 0.0 else -1
	if _time_shown >= 0:
		apply(from_command(_time_shown))


## Which time of day this knob was last shown, or -1. For the tests.
func time_shown() -> int:
	return _time_shown


func _turn(facing: Basis) -> void:
	var was: int = at_stop()
	super._turn(facing)
	if at_stop() != was:
		chose_time.emit(at_stop())


## LET GO, AND IT SHOWS WHAT THE LEVEL HAS ON -- which is where the hand left it whenever the level agreed.
func _on_released() -> void:
	if _time_shown >= 0:
		value = from_command(_time_shown)
