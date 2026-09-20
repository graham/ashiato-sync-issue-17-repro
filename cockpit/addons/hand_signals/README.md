# Hand Signals

**Body-relative gesture recognition for VR**, built on one idea:

> A signal is not a shape to be classified. It is a **path through places** — the hand is
> above the shoulder, or straight out at ninety degrees, or crossed over the head — and the
> signal is the order those places are visited in.

Everything follows from that. A zone can be **drawn**, so a player can be shown where to put
their hands. A signal can be **walked by a test** with no headset and no input. And a near
miss is a near miss for a reason you can say out loud — *"the left hand was nowhere"* —
rather than a number from a classifier that was 0.61 when it wanted 0.7.

Copy `addons/hand_signals/` into a project and enable it.

| Class | What it is |
|---|---|
| `SignalZones` | Where a hand can be, in ARM-LENGTHS. The one piece of arithmetic. |
| `SignalBook` | Every signal, as data. Four timing modes. |
| `SignalReader` | The body frame, and what the hands are saying in it. |
| `SignalGhosts` | The targets, drawn in the air, that teach somebody the signal. |

## In arm-lengths, not in metres

Every position is in **reaches**: shoulders to controller with the arm straight out. A zone
at `x = 0.98` is "arm straight out" for a player of any size, and one table fits somebody of
1.5 m and somebody of 2.0 m. Metres cannot do that — "hands at 1.6 m" is overhead for one
player and chest height for another, and the second can never make the signal at all.
`SignalReader.calibrate` measures the player's own from both arms held out.

## Wiring it up

`SignalReader` must be a **child of the XR origin** — every subtraction it does is between
children of one node, which is what makes it correct on a moving deck. Give it anything with
these six members and it will never ask what game it is in:

```
origin  camera  desktop_camera  using_xr  left_hand/right_hand  grip_left/grip_right
```

```gdscript
var reader := SignalReader.new()
reader.rig = my_rig
origin.add_child(reader)
reader.signalled.connect(func(id, strength): ...)   # once, on the frame it completes
reader.holding.connect(func(id, strength): ...)     # every frame a continuous one runs
```

It **announces and does not act**. It has no idea that a `come_ahead` makes an aeroplane
move; the game decides.

## The rate is part of the message

Four modes, and the difference between them is timing:

| | |
|---|---|
| `HOLD` | one pose, kept still for a moment |
| `ONCE` | poses in order, inside a time limit |
| `CYCLE` | poses alternating, over and over — **carries a number: how fast you are waving** |
| `CIRCLE` | a hand going round inside one zone |

`CYCLE` exists because half of marshalling is analogue. Beckon slowly and the aeroplane
creeps; beckon hard and it comes. And a normal stop and an emergency stop are the same arms
over the same head — **nothing tells them apart but speed**, which is exactly what tells
them apart on a real apron.

## The book is the real thing

The signals shipped are the standard ones: ICAO Annex 2, Appendix 1, plus the deck signals a
carrier launch runs on. A player who learns them has learned the real thing. Replace
`SignalBook.SIGNALS` with your own table and nothing else changes.

## The guide waits for you

`SignalGhosts` draws the pose the player is meant to make and lights each target as a hand
arrives. It **advances when your hands are actually in the pose**, and otherwise waits — an
earlier version ran on a metronome, and the targets moved away before you reached them while
the matcher sat waiting for the pose you were being led away from. Doing the right thing
looked like the game disagreeing with you. It still loops for somebody standing still,
because a beckon that never repeated would be a still picture of a movement.
