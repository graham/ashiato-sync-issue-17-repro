extends RefCounted
class_name ControlCatalogue
## EVERYTHING A COCKPIT CAN BE BUILT OUT OF, and how to make one.
##
## The parts bin for the cockpit builder. A player opens the board, picks a lever off this
## list, and it appears in front of them to be moved into place -- see `PilotRig.add_control`
## and `CockpitLayout`, which is where it ends up written down.
##
## ---------------------------------------------------------------------------------
## WHY THIS IS A LIST AND NOT A SCAN OF THE FOLDER
## ---------------------------------------------------------------------------------
##
## Every control in the game is a class in `objects/controls`, so a directory listing would
## be shorter than what is below and would never go stale. It would also offer the player
## `VehicleControl`, which is the base class and builds no meshes at all, and `PintleGun`,
## which must not be placed by hand at all (see below) -- and a parts bin whose entries do
## not all WORK is worse than one somebody has to remember to add a line to.
##
## What is in here is a decision, then, and the ones left out are the interesting half:
##
##   * `VehicleControl` is the base class. It has no shape and does nothing.
##   * `RudderIndicator` is a gauge and not a handle. It is not a VehicleControl, no hand
##     can take hold of it, and a parts bin entry that cannot be picked up again once it is
##     put down is a trap.
##   * `PintleGun` IS the gun. Where it sits is not a layout decision -- the simulation says
##     where that mount is bolted, because that is where the round leaves from, and a gun
##     dragged somewhere else would fire from where it used to be. See
##     `CockpitStation._fit_the_gunners_stick`, which places it from the mount table.
##
## A `GunTrigger` is here, because that one IS a layout decision: it is a grip on the
## console beside the joystick, and which side of the joystick is exactly the sort of thing
## the builder exists to settle.
##
## So are `RudderPedals`, though no hand works them: they show the rudder, and where in the footwell they stand is a
## layout decision like any other. `CockpitStation._fit_the_pedals` puts them under the column, and a saved cockpit
## moves them from there -- or, being a file that wins outright, takes them out if it was saved before they existed.
##
## And a `TimeOfDayDial` is a `DetentDial` with the level's times on it: a class of its own, because a saved layout keeps
## a part's name and not its stops. See it.
##
##   * `CameraKeypad` is the three keys on the back of a `DirectorCamera`, and is offered nowhere. It
##     is bolted to a camera and reaches the player's hands through `VehicleControl.carries` -- a
##     keypad standing on a console with no camera behind it would be three keys wired to nothing.
##     A `DirectorCamera` IS offered, because where you stand a camera is the layout decision of the
##     whole bin.
##
## And a `SignalLamp`, last, since 2026-09-19: *"let's have the light gun (like the director camera) is
## optional, not always present and can be loaded via the ipad."* Until then it was kit, holstered at every
## seat of every craft. It is one to a seat and arrives in its holster (`PilotRig._add_a_lamp`), and other
## machines learn of it from its own channel rather than from the layout (`SignalLamp`).

## THE PARTS, IN THE ORDER THEY ARE OFFERED.
##
## Flying controls first, then the levers that configure the aircraft, then the panel
## furniture -- the switches, knobs, dials and screens that a cockpit is mostly made of.
## Roughly the order a cockpit gets built in, and therefore the order somebody building one
## wants to read it.
##
## TWO GEAR CONTROLS, ON PURPOSE. `GearLever` is a knob in a slot on a pedestal between two
## pilots; `GearHandle` is an arm with a lit wheel on a fighter's left console. The shape IS
## the difference -- one is reached for by a crew and the other by a hand that never leaves
## the throttle -- and a shape behind an export flag is a shape nobody finds.
##
## THE CLASS ITSELF AS THE VALUE. A global class name in GDScript is a value, so this needs
## no paths and no `preload`, and a class that is renamed breaks here at parse time rather
## than at the moment somebody presses the button.
const PARTS: Array[StringName] = [
	&"FlightStick",
	&"ControlYoke",
	&"SteeringWheel",
	&"ThrottleLever",
	&"PlungerThrottle",
	&"CollectiveLever",
	&"BrakeLever",
	&"FlapsLever",
	&"GearLever",
	&"TrimWheel",
	&"TiltLever",
	&"SweepHandle",
	&"DropLever",
	&"AirbrakeLever",
	&"GearHandle",
	&"GunTrigger",
	&"RudderPedals",
	&"CrewButton",
	&"CommandButton",
	&"ToggleSwitch",
	&"GuardedToggleSwitch",
	&"RotaryKnob",
	&"DetentDial",
	&"TimeOfDayDial",
	&"MfdPanel",
	&"MapScreen",
	&"DirectorCamera",
	&"SignalLamp",
]


## ONE OF EACH, BY NAME. Built fresh every call rather than kept in a `const`, because a
## class is a value here and a dictionary of them in a constant is a dictionary of values
## that outlive the scene that asked for them.
static func _bench() -> Dictionary:
	return {
		&"FlightStick": FlightStick,
		&"ControlYoke": ControlYoke,
		&"SteeringWheel": SteeringWheel,
		&"ThrottleLever": ThrottleLever,
		&"PlungerThrottle": PlungerThrottle,
		&"CollectiveLever": CollectiveLever,
		&"BrakeLever": BrakeLever,
		&"FlapsLever": FlapsLever,
		&"GearLever": GearLever,
		&"TrimWheel": TrimWheel,
		&"TiltLever": TiltLever,
		&"SweepHandle": SweepHandle,
		&"DropLever": DropLever,
		&"AirbrakeLever": AirbrakeLever,
		&"GearHandle": GearHandle,
		&"GunTrigger": GunTrigger,
		&"RudderPedals": RudderPedals,
		&"CrewButton": CrewButton,
		&"CommandButton": CommandButton,
		&"ToggleSwitch": ToggleSwitch,
		&"GuardedToggleSwitch": GuardedToggleSwitch,
		&"RotaryKnob": RotaryKnob,
		&"DetentDial": DetentDial,
		&"TimeOfDayDial": TimeOfDayDial,
		&"MfdPanel": MfdPanel,
		&"MapScreen": MapScreen,
		&"DirectorCamera": DirectorCamera,
		&"SignalLamp": SignalLamp,
	}


## MAKE ONE. Null for a name that is not in the bin, which is what a stale saved layout
## looks like: a cockpit written down before a control was renamed should lose that one
## lever and keep the rest, rather than failing to load at all.
static func make(part: StringName) -> VehicleControl:
	var bench: Dictionary = _bench()
	if not bench.has(part):
		return null
	return (bench[part] as GDScript).new() as VehicleControl


## WHETHER THIS IS SOMETHING THE BUILDER MAY PLACE. Asked by the layout reader before it
## trusts a name out of a file, and by the tests.
static func has(part: StringName) -> bool:
	return _bench().has(part)


## WHICH PART A CONTROL ALREADY IN A COCKPIT IS, for writing one down.
##
## The script's own global name, which is the same string `make` takes -- so a cockpit can
## be saved and read back without a second table mapping one to the other. Two tables is how
## the mount rule came to have three versions.
static func part_of(control: VehicleControl) -> StringName:
	var script := control.get_script() as GDScript
	return StringName(script.get_global_name()) if script != null else &""


## WHAT TO WRITE ON THE BUTTON. The class name with its words split apart, which for every
## one of these is what a person would have called it anyway: FLIGHT STICK, TRIM WHEEL.
static func label_of(part: StringName) -> String:
	var out: String = ""
	for letter in String(part):
		if letter == letter.to_upper() and not out.is_empty():
			out += " "
		out += letter
	return out.to_upper()
