extends RefCounted
class_name Bind
## WHAT A HAND CONTROLLER'S FINGERS DO, AND WHO DECIDES.
##
## A hand controller has more on it than a grip. There is a trigger under the index finger,
## two buttons under the thumb, a mini joystick that also clicks in, and a menu button. In
## a cockpit game every one of those wants to mean something DIFFERENT depending on what
## the hand is holding: the trigger fires the gun you have hold of, and a thumb button on a
## throttle is not the same thumb button on a control column, because those are not the
## same object.
##
## So the binding is a property of the CONTROL, not of the rig -- and of the CLIPBOARD while
## it is up, which answers the same question the same way: see `ClipboardPage.bindings`.
## The rest of this paragraph was written about controls and is true of the board too.
## `VehicleControl.bindings`
## returns a table from one of the inputs below to one of the actions below, each control
## class answers for itself, and `PilotRig` does no more than look it up and carry it out.
## This is the same rule the command bus already follows -- a new lever is a class and not
## another branch in the rig -- extended from "what does moving it do" to "what do the rest
## of your fingers do while you are moving it".
##
## TWO INPUTS ARE RESERVED AND CANNOT BE BOUND.
##
## GRIP is always take-hold-of-this. A grip that meant something else on one lever would be
## a lever you cannot pick up, and there would be no way to discover that except by failing
## to pick it up. See `PilotRig` for the tap-to-latch rule layered on top of it.
##
## MENU is always the clipboard, on either hand. A menu button that opened the menu only
## sometimes is a menu button people press twice.
##
## AND SINCE 2026-09-15 THE TRIGGER IS RESERVED TOO, ON THE CONTROLS THAT ARE PINCHED, and
## only while such a control is actually in the hand. See `Take` below and
## `PilotRig._bindings_for`. Until that date this paragraph read "GRIP is always
## take-hold-of-this, EVERYWHERE, ON EVERY CONTROL", and that was the truth: there was no
## pinch anywhere in this game, on any control, and one grab took a flight stick, a bat
## switch and an MFD key alike.
##
## THAT IS WORTH SAYING OUT LOUD because it will be misremembered. The request that built
## the pinch referred to "the pinch gesture we built earlier"; nothing of the sort had been
## built, and the sentence above is what was there instead. `tests/pinch.gd` is the gate
## that first failed, and its RED reading is the record of the day there was no pinch.


## WHICH FINGER TAKES HOLD OF A CONTROL. A property of the control's KIND, answered by
## `VehicleControl.taken_by`, and the reason a new gesture needed no new input path: GRIP
## and TRIGGER were already two separate things here.
##
## THE LINE IS WHAT YOUR HAND DOES, and it is the user's own sentence: "it's more natural to
## grab joysticks or wheels and 'pinch' buttons and switches." A thing you wrap a hand round
## takes the GRIP. A thing you operate with a fingertip takes the PINCH.
##
## THREE VALUES AND NOT A BINDABLE INPUT. This is not a table entry a control may fill in with
## anything -- a control taken by the thumb button that also browses the craft list would be
## a control nobody could find and nobody could let go of. The choice is between exactly
## these three. NONE is reserved for a display whose glass has no controls.
enum Take {
	## THE WHOLE HAND CLOSES ROUND IT: a stick, a yoke, a wheel, a lever, a quadrant, a gun
	## grip, a handle. The default, because most of what is in a cockpit within arm's reach
	## is something to be held, and because a control that forgot to answer should still be
	## pickable up.
	GRIP,
	## A FINGERTIP WORKS IT: a bat switch, a push button, a knob, a selector, a key on a
	## bezel. Small things you flick, press or roll, where a closing fist is a fist covering
	## the thing it is aiming at.
	PINCH,
	## A DISPLAY WITH NO TOUCH OR BEZEL CONTROLS. It can be moved by BUILD,
	## but ordinary hands never take it while flying. Last so the established
	## GRIP/PINCH numeric values remain stable.
	NONE,
}

## AND THE TWO DIFFER IN THEIR RELEASE, WHICH IS NOT A DETAIL.
##
## A GRIP LATCHES. Tap it on and tap it off: the hand stays on the control until the grab
## button is pressed again, and a long squeeze released is an ordinary release. That is what
## makes holding a lever at 300 kph a decision rather than a hand cramp. See
## `PilotRig._grip_of`.
##
## A PINCH NEVER LATCHES. Any release of the trigger is a full release, however brief the pull
## was. Asked for in those words on 2026-09-15 -- "any release is a full release, this makes
## working with switches (which you only want to grab until you have the setting you want)
## easier" -- and the reason is inside the sentence: you hold a switch only until it is where
## you want it. A latch is right for a lever you fly with for an hour and wrong for a switch
## you flick, where it would leave your hand stuck to the switch after every flick, to be got
## off with a second tap nobody asked to make.
##
## SO THE LATCH BELONGS TO THE GESTURE, NOT TO THE HAND. A fist tapped while the trigger is
## pinching something latches nothing: see `PilotRig._in_the_fist`, and `tests/pinch.gd` for
## what happened before it existed.

## THE INPUTS A CONTROL MAY SPEAK FOR. Named for the finger and not for the hardware, since
## `ax_button` is the lower thumb button on the right hand and the lower one on the left,
## and which letter is printed on it is not something a binding should have to know.
enum {
	## The index finger. Analog: a binding may read it as a level or as a press.
	TRIGGER,
	## The lower thumb button -- A on the right hand, X on the left.
	THUMB_LOW,
	## The upper thumb button -- B on the right hand, Y on the left.
	THUMB_HIGH,
	## The mini joystick, as a Vector2.
	STICK,
	## Pressing that joystick in.
	STICK_CLICK,
}

## HOW MANY INPUTS THERE ARE, for anything that wants to walk them. Kept beside the enum
## because an unnamed trailing enumerator is a thing people delete.
const COUNT: int = 5

## WHAT AN ACTION DOES. The four kinds differ in WHEN they act, which is the part that is
## easy to get wrong and impossible to see from a call site that only says "flaps".
enum Kind {
	## EVERY FRAME THE INPUT IS DOWN, a bit on the control frame. The server edge-detects
	## it, which is the only place that can: an input frame is replayed during a rollback,
	## so a "just pressed" worked out on this machine fires a magazine per replay.
	FRAME_BIT,
	## EVERY FRAME, an analog input into a named axis of the control frame.
	FRAME_AXIS,
	## ONCE, ON THE PRESS. A command on the bus, which is where a configuration lives.
	COMMAND,
	## ONCE, ON THE PRESS. Somewhere local -- the clipboard. Never on any wire: what page
	## somebody is looking at is nobody else's business.
	LOCAL,
}

## WHAT A LOCAL ACTION MAY ASK FOR. Nothing here goes on any wire: which page somebody is
## looking at, and how far down it they have got, is nobody else's business.
enum Local {
	## Put the board up, or away.
	CLIPBOARD,
	## Back up the page, half a screen at a time.
	SCROLL_UP,
	## Further down it.
	SCROLL_DOWN,
	## Take the control this hand is holding out of the cockpit. Only bound while the
	## builder is on -- see `PilotRig._building_bindings` -- because a thumb button that
	## deleted your throttle in flight would be the last bug anybody reported.
	BIN,
	## Stop moving the controls and start WORKING them, without leaving the builder. The
	## other half of laying a cockpit out: you put a lever somewhere, and then you have to
	## find out whether you can actually use it there.
	TRY_IT,
	## MOVE ABOUT THE BOARD with the mini joystick: up and down walk the highlight through
	## what is on the page, left and right turn to the tab beside this one. Acts on the flick
	## -- the stick crossing half travel -- and reads WHICH WAY it went, so one entry is the
	## whole of a four-way pad.
	NAVIGATE,
	## PRESS WHATEVER IS HIGHLIGHTED, exactly as a finger arriving on it would. The board can be
	## worked without reaching for it, which on a long flight is most of the time.
	PRESS_HIGHLIGHTED,
	## THE NEXT TAB, round to the first after the last.
	TAB_NEXT,
	## SNAP ON OR OFF, for whichever quantity the grid's stick adjusts. On the joystick's click of the hand carrying a
	## control while the cockpit is being built -- see `PilotRig._building_bindings` and `PlacingGrid.toggle`.
	SNAP_TOGGLE,
	## A COARSER OR FINER GRID, one step per flick of the joystick up or down, and again every quarter second while it is
	## held over. Reads which way it went, like NAVIGATE. See `PlacingGrid.step_by`.
	SNAP_STEP,
	## THE SNAP BOARD, up on the hand carrying the control, or away. On that hand's trigger. See `SnapBoard`.
	SNAP_BOARD,
}


## A BIT ON THE CONTROL FRAME, set for as long as the input is held.
##
## `Sim.BUTTON_FIRE` and the seat and craft buttons are all this. A level and not a press,
## deliberately: see Kind.FRAME_BIT.
static func frame(bit: int) -> Dictionary:
	return {"kind": Kind.FRAME_BIT, "bit": bit}


## AN ANALOG INPUT INTO ONE AXIS OF THE CONTROL FRAME.
##
## `axis` is a key of the frame `PilotRig.read_controls` builds -- "brake", "pitch",
## "roll", "rudder" -- or "lever_rate", which is not on the frame at all but is the rate the
## rig winds its own throttle at. `scale` is applied to the reading, so a stick that has to
## be pushed forward for nose down is -1.0 rather than a sign buried in the rig.
##
## FROM A VECTOR2 INPUT, `axis` may name a pair: "pitch" takes y, "roll" takes x. Which one
## comes from `component`.
static func axis(name: String, scale: float = 1.0, component: int = -1) -> Dictionary:
	return {"kind": Kind.FRAME_AXIS, "axis": name, "scale": scale, "component": component}


## ONE VALUE ONTO ONE BUS CHANNEL, sent on the press.
##
## Absolute, so it needs to know nothing about where the channel is now. Two of these on
## two buttons is how a two-position switch is worked without a lever.
static func command(channel: int, value: int) -> Dictionary:
	return {"kind": Kind.COMMAND, "channel": channel, "value": value, "step": 0,
		"wrap": false}


## MOVE A BUS CHANNEL BY `delta` NOTCHES, sent on the press.
##
## Reads where the channel IS from the craft -- off the wire, like everything else shared --
## and clamps to the range the craft is fitted with, so a four-notch flap gate stops at four
## on the aircraft that has four and at one on the aircraft that has a switch. `wrap` turns
## the clamp into a cycle, which is what a weapon selector wants and what a flap lever does
## not.
static func step(channel: int, delta: int, wrap: bool = false) -> Dictionary:
	return {"kind": Kind.COMMAND, "channel": channel, "value": 0, "step": delta,
		"wrap": wrap}


## MOVE A BUS CHANNEL TO THE NEXT OF `stops`, round to the first after the last, sent on the press.
##
## For a channel whose fitted range is not the list of things it can select. The plane fits Weapon at range 3 and
## carries two missile stations, 0 and 1, because the same channel is "guns hot" and "ammunition" on other kinds -- so a
## `step` wrapped through 0..3 put the lower thumb on 2 and 3, which select nothing, and the sight said NO MISSILE ON
## THIS STATION for half the presses. `stops` is the list the simulation gives, in its own numbers, never positions.
## A channel sitting on something not in the list goes to the first stop.
static func step_among(channel: int, stops: Array) -> Dictionary:
	return {"kind": Kind.COMMAND, "channel": channel, "value": 0, "step": 1, "wrap": true,
		"stops": stops.duplicate()}


## THE TRIGGER, WORKED AS A TRIGGER: how hard it is pulled, and that it is pulled at all.
##
## A trigger is the one analogue thing on a hand controller and it had been wired as a
## switch -- half travel or nothing, which is a button with extra steps. A finger knows the
## difference. Easing one walks a cannon down to single rounds and squeezing it opens up,
## and that is how a gun with a rate of fire is worked; the hardware reports the number and
## the only thing standing between the two was this binding.
##
## BOTH, AND THE BIT ON PURPOSE. `Sim.BUTTON_FIRE` still means "firing at all", and
## the server still needs it: a keyboard has no axis, so a desktop gunner sets the bit and
## the simulation reads it as a full pull. One binding, either machine.
##
## Every control with a trigger uses this rather than writing the pair out, so there is one
## place that decides what pulling a trigger is.
static func fire() -> Array:
	return [frame(Sim.BUTTON_FIRE), axis("trigger")]


## SOMETHING ON THIS MACHINE AND NOWHERE ELSE. See Kind.LOCAL.
static func local(what: int) -> Dictionary:
	return {"kind": Kind.LOCAL, "what": what}


## NOTHING, SAID OUT LOUD.
##
## For a control that deliberately takes an input away rather than leaving it to the global
## set: a hand on a gun trigger must not still be braking with the same finger. An absent
## key falls through to the global binding; this one does not.
static func nothing() -> Dictionary:
	return {"kind": Kind.FRAME_BIT, "bit": 0}


## WHETHER AN INPUT IS ANALOG, which decides how the rig reads it.
##
## The trigger and the mini joystick are; the thumb buttons and the click are not. A binding
## does not say which it wants -- the hardware already decided -- so this is asked of the
## input rather than declared per action.
static func is_analog(input: int) -> bool:
	return input == TRIGGER or input == STICK


## ---------------------------------------------------------------------------------
## SAYING WHAT A BINDING DOES, IN ENGLISH
## ---------------------------------------------------------------------------------
##
## The HELP page on the clipboard is drawn from the LIVE binding tables rather than from a
## list of sentences somebody keeps in step, and this is what turns one into the other.
##
## It matters because the alternative had already gone stale. The only legend this game had
## was a line printed to stdout by `PilotRig._enter_desktop` -- which a player who
## double-clicks the game never sees, and which in a headset is invisible twice over -- and
## it said "F1-F10 a type" while eighteen keys were bound to eighteen craft. A page written
## from the table cannot say that.

## WHAT AN INPUT IS CALLED, for a person. Named for the finger, like the enum: which letter
## is printed on a thumb button depends on which hand it is under.
static func input_name(input: int) -> String:
	match input:
		TRIGGER: return "trigger"
		THUMB_LOW: return "lower thumb button"
		THUMB_HIGH: return "upper thumb button"
		STICK: return "mini joystick"
		STICK_CLICK: return "joystick click"
	return "?"


## Every input, in enum order, for anything that walks them. Dictionary order is insertion
## order in GDScript, so a legend built by walking a binding table would be laid out in
## whatever order each control happened to write its own -- which is a page that moves about
## between one craft and the next.
static func inputs() -> Array[int]:
	return [TRIGGER, THUMB_LOW, THUMB_HIGH, STICK, STICK_CLICK]


## WHAT ONE ACTION DOES, in words. Takes what a `bindings()` table holds, which may be a
## single action or an Array of them -- `fire()` is two.
static func says(action: Variant, names: Dictionary = {}) -> String:
	if action is Array:
		var parts: PackedStringArray = []
		for one in action:
			var said: String = says(one, names)
			if said != "" and not said in parts:
				parts.append(said)
		return " and ".join(parts)
	if not (action is Dictionary):
		return ""
	var what: Dictionary = action
	match int(what.get("kind", -1)):
		Kind.FRAME_BIT:
			return _bit_name(int(what.get("bit", 0)))
		Kind.FRAME_AXIS:
			return _axis_name(String(what.get("axis", "")),
				float(what.get("scale", 1.0)))
		Kind.COMMAND:
			var channel_id: int = int(what.get("channel", -1))
			var channel: String = String(names.get(channel_id, Sim.channel_name(channel_id)))
			var step_by: int = int(what.get("step", 0))
			if not (what.get("stops", []) as Array).is_empty():
				return "the next %s" % channel
			if step_by == 0:
				return "%s to %d" % [channel, int(what.get("value", 0))]
			return "%s %s a notch" % [channel, "up" if step_by > 0 else "down"]
		Kind.LOCAL:
			return _local_name(int(what.get("what", -1)))
	return ""


## A BUTTON BIT, NAMED OFF `Sim`'s OWN CONSTANTS. Zero is `Bind.nothing()`, which is an
## entry that deliberately takes an input away -- a gun grip does it to the brake -- and a
## legend that left it out would show the brake on a finger that is not braking.
static func _bit_name(bit: int) -> String:
	match bit:
		0: return "nothing here"
		Sim.BUTTON_SEAT: return "next seat in this craft"
		Sim.BUTTON_USE: return "next craft"
		Sim.BUTTON_MENU: return "the clipboard"
		Sim.BUTTON_KIND: return "next KIND of craft"
		Sim.BUTTON_FIRE: return "fire"
		Sim.BUTTON_JOIN: return "sit with that player"
		Sim.BUTTON_LOCK: return "lock the target ahead"
		Sim.BUTTON_LAUNCH: return "launch a missile"
	return "button %d" % bit


## AN AXIS OF THE CONTROL FRAME. `lever_rate` and `trim_rate` are not on the frame at all --
## they are what the rig winds its own lever and wheel with -- and both are named for the
## thing a player can see moving rather than for the variable.
static func _axis_name(axis: String, scale: float) -> String:
	var reversed: String = " (pushed forward)" if scale < 0.0 else ""
	match axis:
		"pitch": return "pitch" + reversed
		"roll": return "roll"
		"rudder": return "rudder"
		"brake": return "brake"
		"trigger": return "how hard the gun fires"
		"lever_rate": return "wind the throttle"
		"trim_rate": return "wind the trim"
	return axis


static func _local_name(what: int) -> String:
	match what:
		Local.CLIPBOARD: return "the clipboard"
		Local.SCROLL_UP: return "up the page"
		Local.SCROLL_DOWN: return "down the page"
		Local.BIN: return "bin the control in this hand"
		Local.TRY_IT: return "move the controls, or work them"
		Local.NAVIGATE: return "move the highlight (up, down) or the tab (left, right)"
		Local.PRESS_HIGHLIGHTED: return "press what is highlighted"
		Local.TAB_NEXT: return "the next tab"
		Local.SNAP_TOGGLE: return "snap to grid on or off"
		Local.SNAP_STEP: return "a coarser grid (up) or a finer one (down)"
		Local.SNAP_BOARD: return "the snap board"
	return "?"
