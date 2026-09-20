extends RefCounted
class_name BoardStyle
## HOW A BOARD IN YOUR HAND IS WRITTEN AND HOW BIG ITS CONTROLS ARE: the clipboard's page, and any other small board a
## hand holds up (the snap board is next), read these rather than keeping numbers of their own.
##
## ONE PLACE, because two boards that each kept a text scale would drift the first time one of them was made more
## readable, and a player would see two different boards for the same kind of thing. Before this the numbers lived in
## `ClipboardPage`, private to it.
##
## Two scales, because they answer two complaints. The writing was hard to read in a headset (2026-09-12), which is
## TEXT_SCALE. The things you press were hard to hit (2026-09-13: "make sure the controls are larger on the iPad but make
## sure everything fits on the screen"), which is CONTROL_SCALE, on top of it, for anything you press and the words on it.

## How big the writing is, against the pixel sizes a page is written in.
const TEXT_SCALE: float = 1.4
## How much bigger a thing you press is than the writing alone would make it: its least height and its words.
const CONTROL_SCALE: float = 1.25

const AMBER := Color(0.95, 0.76, 0.28)
const PALE := Color(0.86, 0.90, 0.92)
const DIM := Color(0.55, 0.60, 0.64)


## A font size for writing, in the page's own pixels.
static func text(pixels: int) -> int:
	return roundi(float(pixels) * TEXT_SCALE)


## A font size for the words on something you press.
static func pressed_text(pixels: int) -> int:
	return roundi(float(pixels) * TEXT_SCALE * CONTROL_SCALE)


## A least height for something you press, in the page's own pixels.
static func reach(pixels: float) -> float:
	return pixels * TEXT_SCALE * CONTROL_SCALE


## THE BOARD ITSELF: the colour every board in a hand is drawn on. One place, because the switch below is judged against it.
const BOARD := Color(0.07, 0.08, 0.10)

## ---- the switch -----------------------------------------------------------------------------------------------------

## A SWITCH, OFF AND ON, as the theme icons every CheckButton on a board inherits: one Theme, built once, set at a page's
## root with `theme = BoardStyle.theme()` and never overridden on a control.
##
## Godot's own unchecked icon is 32 x 16 px with a dot in it, and on the board's near-black the dot was all that showed:
## LABELS did not look like a switch at all (2026-09-13, "make the off switches easier to see"). OFF is now an outlined
## mid-grey pill with its knob on the left, ON a filled amber pill with a dark knob on the right -- different by shape and
## by brightness, not by colour alone.
##
## CheckButton reads eight icons -- checked, unchecked, their _disabled forms, and _mirrored forms of all four -- and no
## hover one (scene/gui/check_button.cpp; `get_icon_list` on 4.7.2 names the same eight). A mirrored layout gets the same
## picture: which side the knob is on says on or off, and must not flip with the text direction.
## `button_checked_color` and `button_unchecked_color` stay white, so the colours are in the pixels the test reads.
##
## NOT THE MFD. `MfdPage` is an instrument in the cockpit with its own glass and 12 px writing, not a board in a hand.
const SWITCH_OFF := DIM
const SWITCH_ON := AMBER
## How much of its alpha a switch that cannot be pressed keeps.
const SWITCH_DISABLED_ALPHA: float = 0.45
## THE LEAST CONTRAST AN OFF SWITCH HAS WITH THE BOARD, as a luminance ratio. 3:1 is the usual floor for the boundary of a
## control. tests/clipboard.gd holds the drawn pixels to it.
const SWITCH_CONTRAST_LEAST: float = 3.0
## THE LEAST SHARE OF AN OFF ICON THAT IS DRAWN. Godot's dot is a few pixels of its 32 x 16.
const SWITCH_COVER_LEAST: float = 0.25
## THE GAP BETWEEN A SWITCH'S WORDS AND ITS PILL, which a CheckButton adds to its least width.
##
## 6 px, and the pill as tall as the board's writing rather than the words on the switch, because of BUTTON LABELS: it
## has a third of 988 px, 324, and asked 300 with Godot's icon and gap of 4. A pill the words' height (61 x 32) with a
## gap of reach(8) asked 339 and widened the row off the glass; 56 x 32 with 7 px still asked 327. 48 x 25 with 6 asks
## 318. Team-lead's floor (2026-09-14) is a 48 x 24 pill and a 6 px gap: a switch that has to be smaller than that is a
## row that needs laying out again, not a smaller switch.
const SWITCH_GAP: int = 6

static var _theme: Theme = null
## The Images the icons were drawn into, by icon name. Kept, because a headless ImageTexture cannot be read back: it asks
## a dummy renderer, which keeps no pixels.
static var _images: Dictionary = {}


## HOW TALL A SWITCH'S PILL IS: the height of the board's writing. See SWITCH_GAP for why not the switch's own words.
static func switch_height() -> int:
	return text(18)


## THE THEME EVERY BOARD'S PAGE WEARS. Built on first use; the same object for every board after that.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	var tall: int = switch_height()
	var wide: int = roundi(float(tall) * 1.9)
	for icon in [["checked", true, false], ["unchecked", false, false],
			["checked_disabled", true, true], ["unchecked_disabled", false, true]]:
		var image: Image = _draw_switch(wide, tall, bool(icon[1]), bool(icon[2]))
		_images[String(icon[0])] = image
		var texture := ImageTexture.create_from_image(image)
		_theme.set_icon(String(icon[0]), "CheckButton", texture)
		_theme.set_icon(String(icon[0]) + "_mirrored", "CheckButton", texture)
	_theme.set_constant("h_separation", "CheckButton", SWITCH_GAP)
	return _theme


## The Image an icon was drawn from, for the tests.
static func switch_image(icon: String) -> Image:
	theme()
	return _images.get(icon) as Image


## ONE PILL, `wide` x `tall`, transparent outside it, and anti-aliased by how much of each pixel the shape covers.
static func _draw_switch(wide: int, tall: int, on: bool, disabled: bool) -> Image:
	var image := Image.create(wide, tall, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var radius: float = float(tall) * 0.42
	var middle: float = float(tall) * 0.5
	var left: float = radius + 1.0
	var right: float = float(wide) - radius - 1.0
	var outline: float = maxf(2.5, float(tall) * 0.1)
	var knob: float = radius * (0.70 if on else 0.62)
	var knob_x: float = right if on else left
	var keep: float = SWITCH_DISABLED_ALPHA if disabled else 1.0
	for y in range(tall):
		for x in range(wide):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			# How far outside the pill: from the segment between its two end centres, less the radius.
			var to_pill: float = p.distance_to(Vector2(clampf(p.x, left, right), middle)) - radius
			var dot: float = clampf(0.5 - (p.distance_to(Vector2(knob_x, middle)) - knob), 0.0, 1.0)
			var colour: Color
			if on:
				var body: Color = SWITCH_ON.lerp(BOARD, dot)
				colour = Color(body.r, body.g, body.b, clampf(0.5 - to_pill, 0.0, 1.0))
			else:
				var ring: float = clampf(0.5 - to_pill, 0.0, 1.0) * clampf(0.5 + to_pill + outline, 0.0, 1.0)
				colour = Color(SWITCH_OFF.r, SWITCH_OFF.g, SWITCH_OFF.b, maxf(ring, dot))
			colour.a *= keep
			image.set_pixel(x, y, colour)
	return image
