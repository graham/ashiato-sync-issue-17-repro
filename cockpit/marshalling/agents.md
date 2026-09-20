# AGENTS.md — marshalling

A different game, on the same ground. Nobody here is flying anything: you stand on a deck or
an apron and move an aeroplane with your hands.

| Item | Value |
|------|-------|
| Doors | `--level=deck`, `--level=stand`, `--level=signals` |
| Depends on | `PilotRig` (inherited), `VehicleView` (to draw a craft), `Sim.geometry_of` (to size one) |
| Does NOT depend on | the simulation, the network, the command bus, C++, any vehicle kind |
| Touches, outside this directory | three lines in `world/boot.gd`, one in `world/desk.gd`, three buttons on `ui/menus/level_menu.gd`, one suite line in each test runner |
| Tests | `marshalling/tests/marshalling.tscn`, in `run_all` as `marshalling` |

## THE ONE DECISION: A SIGNAL IS A PATH THROUGH PLACES

A marshalling signal is not a gesture to be recognised. It is an ordered walk through named
spheres around the player's own body: `chest` then `head`, over and over, is *come ahead*;
`out90` then `crossed`, slowly, is *stop*; the same two done fast is *emergency stop*.

That is the same arithmetic `VehicleControl.offer_hand` already does in every cockpit in the
game — a hand takes hold of whatever is within `REACH` of a grip, and nothing anywhere asks
what shape the hand is in — and everything follows from it:

- A zone can be **drawn**, so a player can be shown where to put their hands. This is the
  whole answer to "how does anybody learn twenty signals".
- A signal can be **walked by a test**, with no headset, no controllers and no frame rate.
- A near miss fails for a reason you can **name** — "the left hand was nowhere" — rather
  than for a number that was 0.61 when it wanted 0.7.

## IN BODY UNITS, AND ONE ZONE THAT IS NOT

Every zone is placed in REACHES: one reach is shoulders-to-controller with the arm straight
out. So the same table fits a player of 1.5 m and one of 2.0 m, and `SignalReader.calibrate`
measures the player's own arm once and keeps it in `user://marshalling.cfg`. Metres cannot
do this: "hands at 1.6 m" is overhead for one player and chest height for another, and the
second can never make the signal at all.

**`deck` is measured from the FLOOR, and that is not an inconsistency.** It is where the
catapult officer's hand goes, and reaching it means genuinely crouching. Written in
shoulder-relative units it could never be touched at all: crouch, and the zone comes down
with you, staying exactly as far below your shoulders as it always was. A target that
recedes for ever. Measured: 1.41 m from the shoulders standing, 0.85 m crouched, against an
arm of 0.78.

**No two zones within a hand of each other**, asserted, for the same reason the cockpit
asserts it about two grips: which of two overlapping targets a hand is in comes down to
arithmetic nobody can see, and the answer changes with a centimetre of tracking noise. The
closest pair is `side`/`knee` at 0.31 m.

## FOUR SHAPES OF SIGNAL, AND THE RATE IS PART OF THE MESSAGE

`HOLD` one pose kept still · `ONCE` poses in order inside a time limit · `CYCLE` poses
alternating · `CIRCLE` a hand going round inside one zone.

`CYCLE` exists because half of marshalling is analogue: "the speed of the signal indicates
the desired speed of aircraft movement" is in the standard itself. Beckon slowly and she
creeps; beckon hard and she comes. Measured: 0.19 waving slowly, 0.97 waving hard.

And the difference between a stop and an EMERGENCY stop is **nothing but speed** — the same
arms, crossed over the same head. `not_before` and `within` are what tell them apart, which
is what tells them apart on a real apron.

## WHAT IS HELD AND WHAT LATCHES — THREE BUGS THAT WERE ONE BUG

The reader goes on reporting a cycling signal as HELD after the hands stop, and it has to: a
slow beckon has over a second between strokes and an aeroplane that stopped between them
would judder up the deck. So for that second the signal you have just STOPPED making is
still arriving, every frame, while the new one arrives once. Three failures came out of that
and all three are the same shape:

1. **A stop was overwritten by the wave before it**, and the jet taxied off the bow.
2. **A turn kept the nosewheel over** for a second after the arms came down, curving the
   aircraft forty degrees off the track while its marshaller was signalling something else.
   It snaked the length of the ship.
3. **Lowering your arms cancelled an order the pilot already had.** `release` erased the
   pending command, so *take tension* — a HOLD, whose signal ends as soon as you move on —
   was never given to the aircraft at all. That one hid until a test made all nineteen
   signals in a row.

The fixes are three rules, and none of them is a special case:

- **A held order counts only while it is the last thing actually made** (`_standing`).
- **A wave stops meaning anything one stroke after it stops** — at the rate it was being
  made at — **and instantly once the hands leave its zones**, which is what happens the
  moment somebody starts a different signal.
- **An order already in the pilot's hands stays there if it LATCHES, and is dropped if it
  was only good while you meant it.** `WHILE_YOU_MEAN_IT` is that list: come ahead, the two
  turns, slow down, move back, run up. A stale latch is harmless; a stale hand on the
  aeroplane is not.

## THE BODY FRAME WAS TURNED ROUND, AND EVERY TEST PASSED ANYWAY

`Basis(UP, yaw)` sends -Z to `(-sin yaw, 0, -cos yaw)`, so recovering a yaw from a facing
means negating **both** terms: `atan2(-facing.x, -facing.z)`. It was written
`atan2(facing.x, facing.z)`, which is 180 degrees out, and the whole zone table sat behind
the player for as long as this directory existed.

**Nothing caught it, and the reason is worth remembering.** Every test put the hands into
the reader's own frame with `SignalZones.place` — so when the frame turned, the targets
turned with it, both halves agreed, and nineteen signals were recognised perfectly. In a
headset it would have been instantly fatal: left reading as right, `forward` somewhere
behind you, `across` on the wrong shoulder.

Two things found it. **`facing()`**, the moment it was wired into anything: it is the only
question in the position whose answer is about the WORLD rather than about the body, so it
is the only one the mistake could not turn round with. And then
`the_hands_the_rig_draws_are_the_hands_the_reader_reads`, which drives the real rig to every
zone and asks the reader where it thinks the hands are — the one loop a test that forces
hand positions cannot check, and now the one that would fail first.

**The rule: a self-consistent test of two halves proves nothing about either.** Somewhere in
the loop something has to be pinned to the outside world.

## EYE CONTACT IS A RULE, AND IT IS THE ONLY THING THAT KNOWS WHICH WAY YOU FACE

The zones are around the player wherever they are pointing, deliberately: turn to watch an
aeroplane come round the corner and "arm straight out to the side" is still your side. So
which way you are facing is a separate question, and `MarshallingLevel` gates on it —
signal with your back to the aeroplane and the pilot tells you they cannot see you. Seventy
degrees either side, which is loose enough to glance at the board and watch a wingtip.

## THE PILOT IS NOT INSTANT, AND THAT IS THE GAME

Every command waits `REACT` (0.45 s) and then arrives through an acceleration. So a
marshaller who calls the stop when the aeroplane is on the mark has already overshot it, and
the whole skill of the job is knowing how far ahead of the mark to call it. An aeroplane
that stopped the instant your arms crossed would need no judgement at all.

**And a pilot who REFUSES is how the order of a procedure is taught.** Nobody taxis with the
chocks in. Being told *"the chocks are in"* at the moment you ask beats a checklist that
says the same thing beforehand.

## A TURN RATE, NOT A NOSEWHEEL ANGLE

`TURN_RATE` is 0.13 rad/s and the lock angle is worked out from it and the wheelbase. Both
halves of that matter.

**It has to be slow.** There is the better part of two seconds between a marshaller deciding
something and the gear doing it — two strokes to read the wave, half a second of pilot, a
second of nosewheel — so a nose that comes round at fifteen degrees a second cannot be
steered by anybody: it is thirty degrees of error before the correction starts. The first
robot to try it snaked fifty degrees either side of the track for the length of the ship.

**And it has to be a RATE.** The same number gives the fighter about 6 degrees of nosewheel
at full taxi (4.5 m/s) and the airliner about 22, because the long aeroplane needs more lock
for the same rate, and neither was typed in.

## THE AEROPLANE IS A NODE, AND THAT IS ALLOWED HERE

The rest of this project is emphatic that a node never writes a position into the
simulation. That rule is not bent: **there is no simulation in these levels at all**, the
same as the hall of cockpits, so there is nothing to write into and nothing to disagree
with. That is what buys "no C++, no new vehicle kind, no pollution".

The body is still the game's own: `craft_plane.tscn` and `craft_airliner.tscn` with
`setup(0, kind)` called on them — the same path the editor preview and the smoke test use,
which needs no session because `kind_geometry` is answered by a `CockpitWorld` built in its
own constructor. `draw()` is never called, because that is the method that would read a pose
out of the simulation, and this craft's pose is ours.

**The price, stated plainly:** a second player cannot sit in this aeroplane. Everything goes
through `MarshalledCraft.command`, which is a dozen verbs wide, so the day a marshaller
wants to be directing a real player's aircraft over the wire, that is what gets
reimplemented — and the levels above it do not find out.

## A POST IS A SEAT

The rig is bolted to a post with `sit_in` and never given a world transform, exactly as a
pilot is bolted to a seat anchor. Not ceremony: park the post on a carrier that is making
way and the player's hands are steady on a moving deck for the same reason a pilot's are
steady at 300 kph. It is the project's one decision, used by a level that has nothing else
in common with the rest of the game.

`MarshalRig` overrides exactly two methods of `PilotRig`. `_seat_the_head` does **nothing**
— a pilot is sat DOWN so their eyes land at the cockpit's 1.35 m, which is right in a
cockpit and wrong on a deck. And `_place_desktop_rig` puts the hands where the mouse says,
because otherwise a desktop player has both hands welded in front of their face and can make
exactly one signal: none.

## THE TEST IS A ROBOT MARSHALLER

Nine checks about hands, and then the whole job done by a robot that looks at where the
nosewheel is, decides what a marshaller would be signalling, and makes that signal properly,
at a real rate, through the real reader. It fails if the zones are wrong, if the book is
ambiguous, if the pilot ignores an order, if the checklist wants things in an order nobody
could do, or if the aeroplane cannot be steered onto the track from where it starts.

Every bug in the "three bugs" section above was found by it and none of them by reading.

It also needs a **lead term** — it steers against where the nose is GOING, not where it is —
and that is a fact about the game rather than about the test: a player who waits to see the
heading come right has already asked for far too much.

## THINGS DELIBERATELY NOT HERE

- **Chocks removed.** The same two poses as *chocks inserted* in the other order, and a
  cycle between two zones is the same cycle whichever end you start at. It wants an `anchor`
  field ("arm only from outside these zones") on that pair alone; a general rule deadlocks a
  cycling signal whose player pauses halfway through it. A pushback level would need it.
- **Wands, and night operations.** Every signal in the book is the same one with a lit wand
  in each hand, so this is a mesh and a light, not a mechanic.
- **A second player in the aeroplane.** See above: a wire format behind `command`.
- **Being run over.** The aircraft passes through the marshaller. The wingtip clearance is
  asserted in the suite instead, which is the useful half of it.
