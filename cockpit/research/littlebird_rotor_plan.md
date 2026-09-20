# The Little Bird on a rotor disc: the plan

The Cessna moved from a lumped wing onto its surfaces, held to the 172S POH. Helicopters
were out of that work. This is the same method for the MH-6M Little Bird, which is a
helicopter and does not fly like an aeroplane.

Read `real_wing_playbook.md` for the method, `learnings/2026-09-19-cessnafm.md` for the
traps, and `learnings/2026-09-17-rotors.md` for what is already wrong with `fly_helicopter`.
This file is the plan for one kind.

## What flies today

`CockpitWorld::fly_helicopter` is a weight-fraction thruster along body up, plus a
full-authority attitude rate servo, plus body-axis quadratic drag. "Translational lift"
is only a label on the 8–16 m/s fade that yaws a human's banked helicopter into its
track. There is no ground effect, no extra lift with speed, no vortex ring, no
autorotation, no rotor torque, no density.

Climb is capped by `drag_vertical = 25` (about 16 m/s, against the MD 530F's 10.5).
Cruise is capped by `drag_forward = 0.6`. Those are the lumped-wing lie in rotor form:
hold one number by fudging another.

## The job, before the physics

`tests/littlebird_flight.gd` already flies a hover, forward flight, a banked turn and a
landing through the pilot's own controls. That is the job suite. Its floors are loose
(climb ≥ 6 m/s against a book 10.5; speed 55–85 against 69 / 78). The book suite is
`tests/littlebird_book.gd`, new, against published figures, with a mutant per check.

## The book (MH-6 / MD 530F)

From `craft/littlebird/sources.md` and the MD 530F data sheet cited there. Mass is the
game's 1,406 kg (3,100 lb MTOW). Do not scale performance to a lighter empty weight:
the game flies at this mass.

| Figure | Book | Band |
|---|---|---|
| Rotor diameter | 8.352 m | the scale, already |
| Mass | 1,406 kg | already |
| Cruise | 135 kt = 69.5 m/s | 0.85–1.10× |
| Vne | 152 kt = 78.2 m/s | cannot hold 90 m/s in level flight |
| Climb, max continuous | 2,070 ft/min = 10.5 m/s | 0.75–1.35× at OGE |
| Hover IGE vs OGE | IGE needs less collective for T = weight | IGE collective < OGE − 0.04 of the lever |
| ETL | 16–24 kt (8–12 m/s) | collective to hold height falls as speed rises through this |
| Autorotation sink | about 1,500–2,500 ft/min = 7.6–12.7 m/s | 6–16 m/s, upright, collective at the bottom |
| Banked turn above ETL | g tan(bank) / v | ≥ 0.85, feet still |
| Hover bank | a side-step, not a turn | nose yaws < 8 deg in 3 s |

Engine: 425 shp cited in `littlebird_flight.gd` (~317 kW). Induced power at OGE hover is
about 140 kW on this disc, so the figure is enough, with margin, and is the power ceiling.

Inertia: OH-6A thesis numbers, scaled by mass (1,406 / 998). ESTIMATE, marked.

## The model

`ashiato-gd/src/cockpit/rotor_disc.hpp`, pure and stateless, no Box3D, rollback-safe.
Momentum theory with Glauert's forward-flight inflow, Cheeseman–Bennett ground effect,
a vortex-ring envelope, and a quasi-steady autorotation (no RPM state on the wire).

Thrust still acts along body up: a Little Bird's disc follows the mast, and pitching
the body is how the cyclic translates. What changes is the **magnitude** of that
thrust, which today is `mass * g * collective` in every phase.

Behind `Handling::rotors`. Default **on** for Little Bird only, the same shape as the
Cessna's `surfaces`. `--set=rotors=1` is the disc; `--set=rotors=0` is the old thruster.
`TuningCard` clips it at `Sim.start`, so a windowed run takes the flag too. Other
helicopters unchanged.

## Phases, named so a suite can ask

| Phase | When | What the disc does |
|---|---|---|
| Ground | skids on, collective below hover | T < weight, no leap |
| IGE hover | height < ~1.25 R, speed < 5 m/s | same T costs less power (or same power gives more T) |
| OGE hover | higher, still slow | full induced power |
| Translating | 8–16 m/s | induced velocity falling; extra lift; bank begins to turn the track |
| Forward | > 16 m/s | cruise and Vne on parasite + remaining induced |
| Vortex ring | descending at ~0.5–1.5 vh, slow, collective up | T falls; not a second hover |
| Autorotation | collective at the bottom, descending | T from inflow, no engine; a flare is a cyclic, not a power recovery |

No RPM on the wire. Autorotation is quasi-steady. A flare that stores rotor energy is
WHAT IS NOT HERE YET.

## Steps

**Step 0 (this file).** Book, phases, cost budget +250 ns/aircraft, same as surfaces.

**Step 1.** `rotor_disc.hpp` + `fly_helicopter` branch + `littlebird_book.gd` behind the
switch. Mutants: no ground effect, no translational lift, no vortex ring, no
autorotation, old thruster (`rotors=0`). Switched off, `littlebird_flight` prints what
it printed before.

**Step 2.** Tighten `littlebird_flight.gd` to the book bands with `--set=rotors=1`.
Pictures: IGE vs OGE collective, ETL acceleration, banked turn, autorotation.

**Step 3.** Price at pinned 30 m/s (a helicopter cruise, not a Cessna's). Flip default
on for Little Bird.

**Step 4.** Write-up, agents.md, learnings, blog. Headset is the user's.

Do not roll this out to the UH-60, Apache or Chinook until the Little Bird has been
shown. They keep the thruster.

## Cost

Budget +250 ns an aircraft a tick, measured in a MEASUREMENT slot, both models pinned
at the same speed. The arithmetic is a handful of sqrts.

## What we will not do

- Blade-element 6DOF, flapping, lead-lag, mast moment
- Rotor RPM as replicated state
- Density with height (same deferral as the Cessna)
- Changing other helicopter kinds
- Claiming a headset feel from a suite
