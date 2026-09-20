extends RefCounted
class_name GlassPointer
## WHICH GLASS A RAY IS ON, AND ONE PRESS PER PULL, for anything that points: a hand's beam, or a mouse on a desk.
##
## Lifted out of `HandBeam` on 2026-09-14. The beam had this and drew a rod; a desk's mouse needed the same choice and
## the same press-once rule, and had neither: `PilotRig` offered the mouse to the clipboard ALONE, so on a monitor the
## desk's two screens could not be clicked at all -- which the join code's keypad, and every menu on the desk, needs.
## Measured before this (tests/desk_screens.gd, "a mouse, on a monitor"): a click on "Fly on your own" and one on "Hall
## of cockpits", at their centres in window coordinates, pressed nothing. Two copies of "nearest glass, let the last one
## go, a held press presses nothing" is the shape `HandBeam` was written to end, so it is one object and both ask it.
##
## NEAREST ALONG THE RAY, AND ONLY THAT ONE: a ray through the clipboard that would also land on a monitor behind it
## presses the clipboard. The glass it was on last and is not now is told to `leave`, so a button does not stay lit.
##
## ONE PULL IS ONE PRESS, kept here and not per glass, so a press held while the ray arrives from ANOTHER glass, or from
## off every glass, presses nothing.

var _pressed: bool = false
var _on: TouchPanel = null


## Aim from `from` along `along` at the nearest of `glasses`, and press there if `pressed` has just gone down. Returns
## how far along the ray that glass is, or -1 when the ray is on none; `on` says which.
func point(from: Vector3, along: Vector3, pressed: bool, glasses: Array[TouchPanel]) -> float:
	var nearest: TouchPanel = null
	var best: float = INF
	for glass in glasses:
		if glass == null or not is_instance_valid(glass) or not glass.is_visible_in_tree():
			continue
		var distance: float = glass.reach(from, along)
		if distance >= 0.0 and distance < best:
			best = distance
			nearest = glass
	if _on != nearest and _on != null and is_instance_valid(_on):
		_on.leave()
	_on = nearest
	var length: float = -1.0
	if nearest != null:
		length = nearest.aim(from, along, pressed and not _pressed)
	_pressed = pressed
	return length


## Pointing at nothing any more: the glass it was on is let go of, and the next press starts fresh.
func let_go() -> void:
	if _on != null and is_instance_valid(_on):
		_on.leave()
	_on = null
	_pressed = false


## The glass the ray is on, or null.
func on() -> TouchPanel:
	return _on
