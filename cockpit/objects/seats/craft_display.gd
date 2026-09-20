extends TouchPanel
class_name CraftDisplay
## A SCREEN IN THE COCKPIT: a `TouchPanel` showing a page of the craft's own state.
##
## The panel does the work -- a Control tree on a SubViewport on a quad, pressed with a
## synthetic mouse event -- and it is deliberately not cockpit-specific, because a main menu
## is the same thing with different words on it. What this adds is the ONE RULE that makes
## an instrument an instrument:
##
##   EVERYTHING ON THE GLASS COMES OFF THE SHARED CRAFT DATA.
##
## A page is handed `state` and draws it. It never asks the simulation anything itself and
## it never reads a local input, which is what makes the copilot's airspeed and the pilot's
## the same number from the same place rather than two answers a round trip apart. Every
## argument about which panel is right disappears if neither of them can have an opinion.
##
## The groundwork for every instrument in the game: an MFD is a screen with buttons down each
## side, an airspeed indicator is the same screen with one number on it, a moving map is the
## same screen again.

## AN INSTRUMENT'S SIZE when its scene says nothing, in metres. A package writes a screen's size only when it is not
## this, so the one number lives here.
const DEFAULT_SIZE: Vector2 = Vector2(0.26, 0.20)


func _ready() -> void:
	# Smaller and unframed by default: an instrument is set INTO a panel, where a menu hangs
	# in the air in front of somebody.
	if size == Vector2(0.40, 0.30):
		size = DEFAULT_SIZE
		# A PANEL IS READ FROM FORTY CENTIMETRES, so what matters is pixels per METRE and not
		# pixels. This was 256 across 0.26 m -- 985 a metre, which is under what a headset
		# can resolve at that range, so the text was soft before the lens ever got to it.
		# 768 is 2950 a metre.
		#
		# IT COSTS ALMOST NOTHING, and the reason is the update rate. A SubViewport here
		# draws on demand -- `redraw` asks for UPDATE_ONCE -- and `Sky` feeds the cockpit
		# screens five times a second, so this is a 768-square render 5 Hz, not 90.
		pixels = 768
	super()


## A PAGE ASKS, AND THE SCREEN SENDS. The page never touches the simulation -- that is the
## rule it is built on -- so the screen, which is a cockpit thing, does the sending for it.
func _ready_page() -> void:
	var page := shown() as CraftPage
	if page != null and not page.commanded.is_connected(_on_commanded):
		page.commanded.connect(_on_commanded)


func _on_commanded(channel: int, value: int) -> void:
	Sim.send_command(channel, value)


## SHOW THE CRAFT'S OWN STATE. Everything on the glass comes from here and from nowhere
## else, so every seat's copy of this screen reads the same number.
func show_state(state: Dictionary) -> void:
	_ready_page()
	var written := shown() as CraftPage
	if written == null:
		return
	written.render(state)
	redraw()
