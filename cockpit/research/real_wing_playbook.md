# Putting an aeroplane on its real wing: the playbook

This is the method that moved the Cessna from the lumped wing (a rate servo with typed damping) onto its own lifting
surfaces (two wing panels, a tailplane and a fin), written so the next kind can be done the same way. The user,
2026-09-19: *"the cessna flight model transition went REALLY well ... preserve the learnings from the new 'real wing'
modelling of the cessna so we can use it to make sure the other planes have really good flight models."*

**The decision:** every kind moves ONE AT A TIME, through the same four steps, each held to its own published book and
to the job the game gives it (for the Cessna, the AI flying the traffic pattern), and priced in a bracketed measurement
before it is switched on. Nothing is typed that a book or a drawing can give.

**What went wrong before:** the first surface model (lane/flightmodel, step 1) kept the lumped wing's drag and thrust
"so the top speed would not move". The top speed was right, and the aeroplane climbed at 4,300 ft/min and glided at
3.4 to 1: holding one number to a book let the rest lie. And lane/pattern's "a bank buys half a turn" (0.54) looked
like the autopilot's fault, when it was the lumped wing's rate servo.

The mechanism itself (what the model computes, the control law, the traps in the physics) is in `../agents.md`, "An
aeroplane on its surfaces" and the two sections under it. The original plan, with its measurements and the user's
decisions, is `flight_model_plan.md`. The two lanes' own accounts are `../../learnings/2026-09-19-flightmodel.md` and
`../../learnings/2026-09-19-cessnafm.md`. This file is the method: read it first, then those.

## 1. Why the Cessna went well

Seven things, in the order they mattered. Keep all of them for the next kind.

1. **The job came before the physics.** The user ordered it: finish the traffic pattern on the old model first, then
   fix the flight model for the Cessna only, and only then the rest. So when the flight-model lane restarted, there was
   already a suite of the Cessna doing its real job (`tests/traffic_pattern.gd`: taxi, take-off, 45-degree entry,
   downwind, base, a 3-degree final, flare, landing, two at once) and a written pass mark for it
   (`traffic_pattern.md` section 10: every number the suite checks, today's value, the limit). "Is the new model
   better?" had an answer that was not a feeling.
2. **A plan with a prototype and a price, before any game code.** Lane/flightmodel's step 0 wrote
   `flight_model_plan.md`, built a stateless model that a prototype could include, and microbenched it (70 to 113 ns an
   aircraft). The user chose the fidelity with the cost in front of them.
3. **Landed behind a switch that was off.** Step 1 put the Cessna on surfaces behind `Handling::surfaces = 0`, with
   every flight suite printing byte-identical numbers switched off. It could merge, be looked at, and wait (it waited while the user
   decided) without risk.
4. **The book, not the old model, was the truth.** `tests/cessna_book.gd` holds the Cessna to the 172S POH, scaled to
   the game's mass: turn, top speed, climb at Vy, glide by energy, take-off roll, roll rate, stall. A table with three
   columns (book, previous model, now) went in every READY and in `agents.md`, so a lie in any column was visible.
5. **One kind, four steps, each landed before the next.** Book, then the autopilot flying it through the pattern, then
   the default flip, then the proofs. Each step was one READY, gated on its own suites plus what it touched, and merged
   before the next began. The whole of lane/cessnafm, all four steps, took about 75 minutes of wall clock.
6. **Priced at the same speed, bracketed, on a quiet machine.** A MEASUREMENT slot, both models pinned to one cruise,
   off/on/off/on. The first unpinned A/B said "8 per cent faster", and that was only the slower cruise shortening the
   collision sweeps.
7. **Every claim had a mutant and a picture.** The lumped model is the turn check's mutant. The before/after pictures
   were charts of measured data or the game's own viewport: the turn rate over textbook, the 30-degree circle against
   the textbook circle, the pattern flown from straight down, and a MovieWriter time-lapse.

## 2. The four steps for the next kind

Brief the lane with these; they are the Cessna's, generalised.

**Step 0, the book and the drawing (no game code).**
- The kind's published figures, from its POH or flight manual or a NACA or manufacturer's document, with the source and
  licence recorded: stall clean and full flap, top speed, cruise at a stated height and power, best-climb speed and
  rate, glide ratio or idle sink, take-off and landing roll, roll rate or pb/2V, and the turn (which is physics:
  g tan(bank) / v). Scale mass-dependent figures to the game's mass.
- The planform, read off the kind's own airframe class, the one the model draws, in its own units: panel spans, chords,
  sweep and dihedral, tail areas and arms, the main-gear station and the drawn lowest aft point. Tail areas are the soft
  part on most drawings; mark each ESTIMATE.
- The inertia: a component-mass estimate, never the hull box's.
- The engine: a propeller is `thrust` falling with speed through `thrust_gone_at` (the line through the book's top
  speed and its climb at Vy) and windmilling at idle; a jet is roughly constant thrust. Drag is the book's CD0. **Do
  not keep the lumped `drag_forward`, `flap_drag` or thrust. They are about five times off.**
- What the kind does in the game (its "pattern"): the airliner's instrument approach, a fighter's carrier trap, the
  glider's thermals, the gunship's orbit. That suite is the acceptance target; write its pass mark down as
  `traffic_pattern.md` section 10 did.

**Step 1, the kind against its book, behind the switch.**
- A `planform_of` case with `tail_underside_station` at the drawn point, and `clmax`/`flap_clmax` in `default_handling`.
- A `<kind>_book.gd` suite modelled on `cessna_book.gd`: each figure, the lumped model as the turn's mutant, the glide
  measured by energy (it must always lose energy), the stall counted only with alpha at the stall.
- `tests/surfaces.gd`'s stiffness guard (roll time constant over three ticks) must pass for the new inertia.
- Switched off, every existing flight suite prints what it printed before. Land it.

**Step 2, the AI flies it at its job, still behind the switch.**
- Run the kind's job suite with `--set=surfaces=1 --kind=<kind>`. Expect the autopilot's lumped-wing assumptions to
  surface; see section 3.
- Fix them so every other kind is unchanged (a zero default that means "as before", as `max_descent_rate` does), and
  say plainly when a fix is geometry every kind shares (`FINAL_STRAIGHT` was, and made the old model better too).
- Land it.

**Step 3, price it, then flip it.**
- MEASUREMENT slot, `rota_probe.gd -- --counts=1000 --blocks=4 --kind=<kind> --set=surfaces=0|1,cruise=<same>`,
  bracketed. Report ns per aircraft per tick, forces and whole tick, and the rollback cost (a client resimulates only the
  craft it pilots). The plan's budget is +250 ns an aircraft; the Cessna cost +75.
- Set `surfaces = 1` for the kind. Run its suites plus `-Tier core`, smoke and every suite that flies it. Expect a
  shared check tuned on the old behaviour to move (the Cessna's moved two: a downwind over land, and smoke's climb), and
  fix the threshold or the geometry, not the clock.

**Step 4, the proofs and the write-up.**
- Charts of measured data (turn over textbook; the steady-bank circle against the textbook circle with
  `cessna_book.gd -- --circles=<file>` as the pattern) and the job flown on each model from straight down, plus a
  MovieWriter time-lapse. In-game only; never the desktop.
- The kind's section in `agents.md` (book table, what changed, what was wrong) and the lane's learnings with a What's
  next.
- **Then someone flies it in a headset.** No suite measures feel. `--set=surfaces=0 --kind=<kind>` flies the old one for
  comparison.

## 3. The traps, all paid for once

Physics and the drawing:
- **The mass centre must move to the centre of gravity.** The hull box's middle is not it (1.67 m aft on the Cessna),
  and surfaces taken about it flip the aeroplane over backwards. `weigh_as_an_aeroplane` moves it.
- **The inertia must be the aeroplane's.** A box's is a bar's with no wing, and aerodynamic damping on it answers
  inside a tick.
- **A box cannot rotate on its wheels.** The hull's underside must rise aft of the mains through the drawn lowest aft
  point, or it never lifts off. **Measure the drawing before blaming it**: the Cessna's drawing was right at 8.55
  degrees; the collision hull put the rudder foot at the box's end and touched at 7.6.
- **A tail that touches early limits lift-off CL**, so the take-off roll is longer than the book when the book lifts off
  near the stall nose-high. That is real; write it down and allow it.

Measuring:
- **Hold EVERY book figure, not the one you were watching.** Keeping the old drag to keep the top speed gave a 4,300
  ft/min climb.
- **Price at the same speed** as the model you replace (`Handling::cruise` pins it), or you have measured the sky.
- **A suite's hand can fake a result.** Trace alpha before believing a stall, a roll or a yaw. Count a stall only with
  alpha at the stall, and fly it through the control law.
- **Measure what the physics names.** Adverse yaw is sideslip, not heading or body yaw rate; a stall break is lift
  falling, not a nose falling.

The autopilot on a real wing:
- **The turn needs no mixer change.** The control law inverts through the surfaces' own moments, damping included, so
  the unedited mixer turns at 0.99 of textbook. A kind that turns short on surfaces has a planform problem.
- **One number may be doing three jobs.** The climb budget sized at cruise was also the steepest descent. On a
  propeller that gave a 2.4-degree final that floated 2.8 km, a 0.8 m/s climb-out and a missed hand-back, all one bug.
  Take a propeller's climb budget at Vy (`engine_climb`, `best_climb_speed`). A jet's budget is still its cruise's:
  check it.
- **Asking for more descent than idle gives is a hunting loop.** The speed runs away, the flaps come out as a speed
  brake, and their lift sets the climb loop hunting. Keep the descent limit inside the idle sink (three quarters of it
  at base speed), and probe it with a clean step from level first (`cessna_book.gd -- --descent`).
- **A rate asked of the law cannot rotate an aeroplane on its wheels.** The ground holds the pitch rate at nothing. Take
  off with a raw stick, or ask the law for enough rate to saturate the elevator.
- **Anything sized on the lumped wing's half-turn tightens by about two.** Circuits, approach radii, pattern sides,
  first-circuit guesses (`turn_expected` answers 1 for a surface kind), and turns designed to end exactly at a gate.
  For the big aeroplanes check `InstrumentApproach`'s radii.

Working:
- **Undo an experiment with its inverse edit, never `git checkout -- <file>`,** which also undoes the earlier fix in the
  same file.
- **A shared suite's wait is a shared clock.** Lengthening smoke's wait surfaced someone else's flake; change the
  threshold instead.
- **Build against `Z:\tanagra\godot-cpp`,** and check the DLL imports no msvcp or vcruntime.
- **`build.ps1`'s `vswhere` writes to stderr;** in PowerShell 5.1, redirected or piped, the build stops. Run it
  unredirected. An SVG chart renders to PNG with `msedge --headless --screenshot`.

## 4. The fleet, in the order planned

Written 2026-09-19. Nothing here is started. Each line is one lane, or two kinds to a lane.

1. **The light twin (`plane`),** most of the island's traffic and the default attacker. Its job: the traffic pattern and
   the attackers' gun runs. It also still needs a drawn fuselage (its model is the collision box).
2. **The Savoia and the glider,** light and raw. The glider's surface numbers are in the sailplane learnings, and the
   sailplane found the lumped model gains energy at low drag: hold the glide by energy.
3. **The big aeroplanes** (airliner 737, jumbo 747, Hawkeye, tanker, gunship and transport), on the plan's 0.5
   augmentation. Their job: the instrument approach and Cape International's crossing runways. The airliner's lumped
   turn is 0.34, so its vectors (sized on 3.2 km) will tighten a lot. Their handling was carried to real mass by ratio in
   lane/liners and never tuned to a book.
4. **The jets on fly-by-wire,** with a game-sized CLmax (45 to 50 m/s with flaps, the plan's decision C) and real
   stalls only once the carrier has arresting wires. Their job: the carrier trap, where the landing rule
   (`touchdown_of`) already judges 7.62 m/s.
5. **The warbirds** (P-51, P-47, P-38, B-17, lane/warbirds): drawn to measured size from 2026-09-19, so their planforms
   can be read straight off their airframe classes.
6. **The Osprey's wing,** last.

Then **delete the lumped path**, once no kind uses it. Two models kept in step is the trap the plan warned of.

Still open from the Cessna: the climb-out is gentle (2.6 m/s against the book's 4.3, the mixer's 0.6 climb share); the
glide is 7.5 against the POH's 9 (a closed throttle windmills fully); ground effect, density with height and P-factor
are cheap extras not yet built.
