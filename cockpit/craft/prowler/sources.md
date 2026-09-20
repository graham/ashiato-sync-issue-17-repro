# Grumman EA-6B Prowler visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/prowler_airframe.gd`). It contains no downloaded mesh, photograph,
texture, trademark or livery.

## The authority for the envelope

The **NAVAIR Standard Aircraft Characteristics "DESCRIPTIVE ARRANGEMENT" three-view of
December 1971**, a US Navy work in the public domain, held on Wikimedia Commons as
[`Grumman EA-6B Prowler 3-view line drawing.png`](https://commons.wikimedia.org/wiki/File:Grumman_EA-6B_Prowler_3-view_line_drawing.png).
It **prints eleven dimensions on the drawing itself**, which is why it is used in preference
to any secondary source. A US Army FM 44-80 recognition three-view
([`GRUMMAN EA-6 PROWLER.png`](https://commons.wikimedia.org/wiki/File:GRUMMAN_EA-6_PROWLER.png),
also public domain) is a shape cross-check with no dimensions on it. Wikipedia's infobox
supplies crew, weights and engines, and nothing else -- see "where the sources disagree".

**A photograph was added afterwards as a second source**, and it is study material only:
[`163529 AJ-500 EA-6B of VAQ-141 Fallon NAS Jan-08`](https://commons.wikimedia.org/wiki/File:163529_AJ-500_EA-6B_of_VAQ-141_Fallon_NAS_Jan-08_(3176069005).jpg),
Jerry Gunner, **CC BY 2.0**, 1503 x 937, a parked EA-6B at NAS Fallon seen near side-on. What
it settled and what it could not is in "the photograph" below.

Neither drawing nor the photograph is incorporated into the game. All are held with their licence table in
`~/godotgames-drafts/2026-09-17/cockpit-prowler/research/`, with the working file
`research-prowler.md` that carries every reading and its method.

Crew roles and mission equipment were cross-checked against the Naval History and Heritage Command's
[`EA-6B Prowler`](https://www.history.navy.mil/content/dam/nhhc/research/histories/naval-aviation/Naval%20Aviation%20News/2000/2004/september-october/prowler.pdf)
history, the Smithsonian's preserved
[`Grumman EA-6B Prowler`](https://airandspace.si.edu/collection-objects/grumman-ea-6b-prowler/nasm_A20190435000),
and the US Navy's [`AN/ALQ-99 Tactical Jamming System`](https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2395340/alq-99-tactical-jamming-system/)
fact file. Public-domain cockpit studies include the Wikimedia Commons
[`rear cockpit`](https://commons.wikimedia.org/wiki/File:EA-6B_Prowler_rear_cockpit.jpg) and
[`SEAD screen`](https://commons.wikimedia.org/wiki/File:EA-6B_Prowler_SEAD_screen.jpg). They are visual evidence,
not textures or meshes shipped by the game.

## The envelope

| | | |
|---|---|---|
| Span, spread | 636 in | **16.154 m** |
| Span, folded | 299 in | **7.595 m** |
| Length, fuselage datum level | 709 in | **18.009 m** |
| Length, parked along the ground | 712.5 in | **18.098 m** |
| Height over the ground under the fin | 195 in | **4.953 m** |
| Height, wings folded | 258.8 in | 6.574 m |
| Tailplane span | 244 in | 6.198 m |
| Main wheel track | 130.5 in | 3.315 m |
| Wheelbase | 206.11 in | 5.235 m |
| Wing area, excluding fillets | 528.9 sq ft | 49.14 m2 |
| Aspect ratio | 5.31 | |
| Mean aerodynamic chord | 130.8 in | 3.322 m |
| Wing sections | tip NACA 64A005.9 MOD, fold 64A008.4 MOD, wing station 33 64A009 MOD | |
| Nose tyre / main tyre | 20 in / 36 in diameter, Type VII | 0.508 m / 0.914 m |
| Crew | four: a pilot and three ECMOs | |
| Empty / maximum take-off | 14,134 kg / 27,896 kg | |

All of the above except the last two rows is printed on the SAC sheet. The last two are
Wikipedia's.

**The drawing is self-consistent before anything is measured off it**: its printed aspect
ratio 5.31 times its printed area 528.9 sq ft gives a span of 53.00 ft, which is its printed
span exactly.

## Datum and axes

The craft origin is the centre of the fuselage box, forward is `-Z`, up is `+Y`, and one
Godot unit is one metre. `ProwlerAirframe` works in **stations**, inches aft of the radome
tip, and **waterlines**, inches above the drawing's own datum; `station()` and `waterline()`
convert. Native collision, flight and station poses remain authoritative.

The model is built with the **fuselage datum level**, which is how the SAC draws it and how
the game flies it.

## Crew and this simulator's deliberate concession

The real aircraft carried one pilot and three electronic countermeasures officers: ECMO-1 sat front-right, with
ECMO-2 and ECMO-3 in the rear row. It did **not** have a conventional copilot. This game's front-right station is
nevertheless typed `Copilot` and carries the same stick, throttle and rudder devices as the pilot because the requested
multi-crew design explicitly calls for two flying seats. It is an accessibility/gameplay concession, not a historical
claim. Both rear stations are `Operator`: the station fitter removes every flight control and leaves three mission
screens. The exterior's four seat silhouettes and screen glow are scale cues only; the interactive furniture comes
from `seat_prowler.tscn` and its authored station package.

The requested "glass cockpit" is interpreted as a transparent gold-tinted glasshouse plus readable mission displays.
It is not a claim that a Prowler had an F-16-style all-glass flight deck; period and preserved cockpit evidence is
largely analogue/CRT, while late upgrades changed mission electronics.

## Moving surfaces and mission pods

The spread/fold wing, outer ailerons, all-moving stabilators and rudder are separate hinged parts. Their four degrees
of freedom are baked by `VatCasting` in the order fold, aileron, pitch, rudder; the ailerons are children of the fold
pivots so the texture applies their local hinge before the outer wing's hinge. The flight linkage drives roll, pitch
and pedals, and a headless contract checks each axis independently.

Three faceted ALQ-99 pods and pylons are modelled as recognition silhouettes, with ram-air-turbine fan faces. The Navy
fact file establishes that the externally carried ALQ-99 receives power from a ram-air turbine and is used by the
EA-6B; exact public pod sections and pylon stations were not found, so their fine dimensions remain visual estimates.

## A Prowler parks nose-up, and that breaks the house convention

The SAC side view draws the aeroplane level and the **ground line raked**. Fitted as circles
off the de-rotated drawing, the two tyres' **lower common tangent -- which is the ground, by
definition, since the aeroplane stands on them -- is at 5.83 degrees**. The fit recovers both
printed tyre diameters as it goes: 19.7 in against the printed 20, and 36.2 in against 36.

Independently, the two printed lengths give `cos-1(709 / 712.5)` = **5.68 degrees**. The two
agree to **0.15 degrees**. The drawing's own extension lines say which length is which: the
709 in pair is vertical on the page and the 712.5 in pair is raked square to the ground, so
709 in is the length in the level frame and 712.5 in is what a parked Prowler occupies along
a deck. The drawn geometry reproduces 712.5 as 710.7.

**So there is no single ground datum for this aircraft.** Every other airframe here is built
to "heights above the ground with the gear down" with the tyre bottoms sharing one datum,
which is `hawkeye_airframe.gd`'s `height()`. In this level frame the Prowler's nose tyre hangs
**0.53 m below** its main tyres. `ProwlerAirframe.GEAR_RAKE` is that measurement and
`ground_at(station)` is a raked plane, not a constant.
`tests/prowler.gd:_the_gear_is_raked_because_a_prowler_parks_nose_up` fails if anybody levels
it, because a convention that is wrong for one aircraft gets "restored" by somebody who knows
the convention and not the aeroplane.

## The photograph: what it settled, and what it could not

**It could not give a number, and no number was taken from it.** The frame is not square on,
and its contrast under the aircraft is too poor to fit either wheel as an ellipse, so the
heading cannot be recovered -- and a fore-aft angle read off a foreshortened photograph is
wrong by an unknown amount. The rake's three agreeing readings all come off the drawing.
`cockpit-prowler-06-model-on-both-tyre-contacts-over-fallon-photo.png` lays the drawn model
over it, pinned on nothing but the two tyre contacts, and the fore-aft overhang in that
picture is the foreshortening, not the model.

**What it did settle, all four qualitative and all four acted on:**

- **A parked Prowler sits nose-up.** Unmistakable without measuring, which is what the
  photograph was wanted for: the drawing's raked ground line is read the right way round.
- **The canopy is one long, nearly-flush, gold-tinted glasshouse in two pieces.** The model
  had drawn it as two blocks standing proud of the spine, which read as a pair of hatches;
  it is glazing on the fuselage's own upper facets now.
- **The fin-tip antenna fairing is a broad, slab-sided, flat-topped pod**, not the tapered
  spindle that had been drawn, which did not read at all in a three-quarter view.
- **The nose gear is a TWIN wheel.** The SAC prints one tyre size and no count, and the model
  had drawn one wheel. **A printed tyre size is not a tyre count**, and a three-view will
  never tell you the difference: the nose gear is drawn end-on in the front view and hidden
  behind itself in the side view. That is a thing only a photograph settles.

## Where the sources disagree, said out loud

- **Length.** The SAC prints 712.5 in (18.098 m) and 709 in (18.009 m), which differ by the
  ground rake. **Wikipedia states 59 ft 10 in (18.24 m)**, which is 0.14 m longer than the
  longest SAC figure and cites no drawing. The model uses the SAC's two and the suite asserts
  both.
- **Height.** The SAC prints **195 in (4.953 m)** to the fin top and, separately,
  **"WING FOLDED 199.6 in" (5.070 m)**. **Wikipedia's 16 ft 8 in (5.08 m) matches the second,
  not the first** -- so the commonly quoted Prowler height looks like a wings-folded figure
  read as an overall height. The model uses 4.953 m. A reader checking this model against
  Wikipedia will otherwise think it is 0.13 m short; it is not.
- **Span** is the one figure nothing disputes.

## What is not settled

**The plan view and the side view disagree by 3.6 per cent about how long this aeroplane is,
and each of them is internally consistent.**

The plan view is isotropic: measured at its own span scale, the outer wing fitted over 85
stations at 3.5 px rms gives a reference area of 523.6 sq ft against the printed 528.9 and a
mean aerodynamic chord of 129.1 in against the printed 130.8 -- neither of which any view's
length went into. Its span reads 632.4 in against the printed 636, and its own printed 244 in
tailplane span agrees with its wingtips to 0.6 per cent. And yet at that scale it draws the
aeroplane 681.0 in long.

The side view's scale has **three mutually independent printed sources** agreeing within 0.8
per cent -- the length between its extension lines, the 206.11 in wheelbase between the two
fitted tyre centres, and the main tyre's own printed 36 in diameter -- and its main tyre is
drawn 53.6 px across by 52.1 px tall, so it is not stretched either. It draws the aeroplane
709 in long.

**I cannot reconcile them and I am not going to pretend to.**

**The model is arranged so that it never has to choose.** Every station comes from the side
view. Every spanwise dimension comes from the printed spans on the front view. The plan view
contributes only planform shape -- sweep and taper, which are ratios and survive any uniform
scale -- and the wing's chords at the plan view's own scale, because that is the scale at
which the drawn wing reproduces the printed area and aspect ratio. The 3.6 per cent comes out
in the wing's trailing edge station, which is the one quantity involved that the drawing does
not print. Built that way the model reproduces every printed number on the sheet.

Stations taken off the plan view are quoted as **a fraction of the plan view's own drawn
length carried onto the side view's 709 in**, rather than in inches at the plan view's scale.
That is what keeps the unreconciled 3.6 per cent out of every station in the model, and it is
why the cockpit and canopy numbers are quoted the way they are.

## Still outstanding

- **The tailplane's dihedral is NOT FOUND.** The front view hides the tailplane behind the
  wing, so it cannot be measured on this drawing. It is drawn flat, and a NOT FOUND is not a
  zero.
- A photograph taken SQUARE ON, or with enough contrast under the aircraft to fit a wheel as
  an ellipse, which would give the heading and turn the rake into a fourth measured reading
  rather than a confirmed sign.
- A square-on cockpit photograph with a known configuration, sufficient to replace the conservative station-shell
  furniture estimates with measured panel angles and dimensions.
- Public pod cross-sections and exact pylon stations. The current three ALQ-99 silhouettes are estimates constrained
  by photographs and the aeroplane envelope, not engineering reproductions.

## Reproducing every measured number

`measure_sac.py`, beside this file, re-derives the page rotation, each view's scale, whether
the plan view is isotropic, the ground rake, the gear rake and the fin top **from the drawing
alone**. It reads nothing out of this write-up, so the two can disagree and one of them be
wrong -- which is how this lane caught its own worst mistake. Put the drawing beside it and
run it:

    python measure_sac.py
