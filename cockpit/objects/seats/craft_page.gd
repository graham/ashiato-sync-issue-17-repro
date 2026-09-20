extends Control
class_name CraftPage
## ONE PAGE ON A SCREEN: an ordinary Control tree, authored in the editor like any other UI.
##
## The base class exists to say what a page may and may not do, because the rule is the
## whole point of the design:
##
##   A PAGE IS HANDED ITS DATA AND DRAWS IT. It never asks the simulation anything, it never
##   reads an input, and it never looks at which seat it is in.
##
## That is what makes two screens in the same aircraft agree. The airspeed on the copilot's
## panel and the airspeed on the pilot's are the same number from the same place -- the
## craft state that is already on the wire for everybody aboard -- rather than two
## instruments each asking their own machine and each getting its own answer a round trip
## apart. Every argument about which one is right disappears if neither of them can have an
## opinion.
##
## Subclass it and override `render`. Anything a page needs that is not in `state` is a gap
## in what the craft shares, and the fix is to share it, not to reach around the back.

## WHAT A PAGE SENDS, which is the only thing it may send.
##
## A page is handed its data and draws it, and that rule is what makes two screens agree. An
## INTERACTIVE page has to be able to change something, and the way it does that without
## breaking the rule is to ask rather than to set: it emits a command, the command goes on
## the bus, the bus comes back as state, and the page draws what came back.
##
## So a switch you press does not move because you pressed it. It moves because the craft
## says it moved -- which is why the copilot's copy of that switch moves at the same moment,
## and why nobody has to write any code for that to be true. It is the same lesson as the
## shared throttle: a control the whole craft owns is read from the wire, not from the hand
## that last touched it.
signal commanded(channel: int, value: int)

## What every page is given. The keys come from `VehicleView.craft_state`, and a page reads
## the ones it cares about and ignores the rest -- so adding a value breaks nothing and a
## page that wants a value nobody publishes yet simply shows a dash.
func render(_state: Dictionary) -> void:
	pass


## A number, or a dash when the craft has not said. An instrument showing 0 for "I do not
## know" is an instrument lying, and it is the kind of lie you only notice in the accident
## report.
static func reading(state: Dictionary, key: String, places: int = 0) -> String:
	if not state.has(key):
		return "---"
	return String.num(float(state[key]), places)
