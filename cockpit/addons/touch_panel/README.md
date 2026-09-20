# Touch Panel

A **world-space UI panel** for Godot 4: an ordinary `Control` scene, rendered to a
`SubViewport`, shown on a quad you can walk up to and press with your finger.

Copy `addons/touch_panel/` into a project and enable it. It depends on nothing else.

```gdscript
var panel := TouchPanel.new()
panel.page = preload("res://ui/my_page.tscn")   # any Control scene
panel.size = Vector2(0.24, 0.30)                # metres
panel.pixels = 620
panel.bezel = true
add_child(panel)

var page: Control = panel.shown()               # talk to the page through this
```

Then give it a hand, every frame, in the panel's own space:

| | |
|---|---|
| `press(at, down)` | a click at the matching pixel, if `at` is within the pane |
| `hover(at)` | the same without clicking, so a button lights up under a finger |
| `point_at(at)` | show the pointer without hovering, for a hand still on its way in |

All three answer whether the point was on the glass at all, so one hand can be offered to
several panels in turn and each says whether it was its business.

## Three things it gets right that are easy to get wrong

**A miss is not clamped, it is refused.** `press` returns `false` when the point is outside
the pane rather than clicking the nearest edge. That is what lets a caller walk a list of
panels with one hand position.

**The pointer does not depth-test.** A panel held at arm's length is looked at from every
angle, and at a glancing one the glass wins the depth test — so the pointer disappears
exactly when it is hardest to aim. It draws in front, always.

**The pointer fades on its own.** Nothing tells a panel that a hand has gone away. Rather
than every caller having to remember to clear it — and the one that forgets leaving a dot
stuck on the glass for the rest of the session — it dims out unless something keeps
pointing at it.

## What it does not do

It does not find your hands for you. Something has to convert a controller pose or a mouse
ray into a point in the panel's space and offer it; that is a handful of lines and it
belongs to the game, because only the game knows which hand is holding the thing.
