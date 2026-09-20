# Which craft nobody has modelled yet

Twenty-five craft, ranked by how much of each one has never been measured against a drawing of a
real thing. `tests/craft_model_audit` prints the two measured columns on every run. The faults
named beside each craft are what a person found by looking, because no measure in this file can
see them.

**Three claims in the first version of this file were wrong, all three in the way the file itself
warns about, and the corrections are kept below rather than quietly edited out.** See "What this
file got wrong on its first day".

## "Not yet updated" is not the same as "boxy"

The question a list like this is usually built to answer -- *which model looks like a crate* --
gets two craft wrong in opposite directions.

**The glider was the least boxy craft in the fleet and was never a counter-example.** Rounded
pod, bubble canopy, T-tail, the DG-1001 Club's published 8.6 m envelope cited in
`craft/glider/sources.md`, a 20 m wing at the manufacturer's optional span, and a wing that was
already tapered 1.28 m at the root to 0.42 at the tip. Somebody sat down with a specification and
built it. A boxiness score sees none of that: it reads 0.12, the third best in the game, both
before and after `lane/glider` remodelled it.

**The pod is drawn from rounded primitives and is the fourth-worst craft in the game.** Its
builder's doc block promises "a rounded pressure hull and a distinct dark canopy". The gallery
shows an open scaffold of black struts around empty air, with no hull of any kind. **The code and
the picture disagree and nothing has ever compared them.** A measure that counted curved surfaces
would have scored it well; `FLAT` gives it 0.31 and puts it 21st of 25.

So the measure is not shape. It is **provenance**: has anybody ever measured this craft against
something outside it?

Three questions, each anchored outside the thing it judges:

1. **Is there a cited drawing, and was the model built from it?** Fourteen kinds carry a
   `craft/<kind>/sources.md`. That file is *not* the answer on its own -- `craft/heli/sources.md`
   is a cited source whose own text says the package "predates the reference-aircraft programme"
   and names `uh60` as its successor. **A cited source that disclaims itself is not a model**, and
   counting source files would have put the fleet's worst craft in its top half.
2. **Who draws it?** A builder named after one aeroplane, or a generic one shared by everything
   with a span, everything with a rotor, or the three ground vehicles. `SkyhawkAirframe` is
   1,391 lines about one aircraft. `_build_helicopter_airframe` is 45 lines about every
   helicopter that is not a UH-60.
3. **Does the drawn thing enclose its crew?** `VehicleView.cabin_room()` answers for every kind,
   and answers `drawn: false` with a reason when the craft encloses nobody. Twenty-four of
   twenty-five say it does not, and the user has ruled those bugs rather than tolerances.

## The list

Worst first. **"Owner" is the point of this column**: a craft with no owner is work nobody has
picked up, not a craft that is fine.

| # | Kind | What is wrong with it | Drawn by | Cited | Owner |
|--:|---|---|---|---|---|
| 1 | `heli` | **A yellow box.** The collision hull is never hidden for a rotor craft, so the body you see is the simulation's cuboid with a stick boom, a plank rotor and two skids stuck on. FLAT 0.97, HULL 0.89. Its own `sources.md` says the package predates the reference-aircraft programme and names `uh60` as its successor -- a documented non-model, not an oversight. | `_build_helicopter_airframe`, generic | yes, and it disclaims itself | **nobody** |
| 2 | `segway` | **The simulation's cuboid, and nothing else.** FLAT 1.00, HULL 0.99 -- the highest reading in the game and the only craft that is its own collision box to three figures. **It is in no photograph**: `craft_gallery_shot.gd` skips it deliberately, "because it has no visible hull in that level". A skip nobody revisits is a craft nobody ever looks at. | the bare `_hull` box | no | **nobody** |
| 3 | `car` | Box on box on four cylinders, with a gun barrel through the roof. No cited vehicle of any kind. FLAT 0.93. | `_build_car_body`, generic | no | **nobody** |
| 4 | `pod` | No hull at all. An open frame of struts around the stations, where the builder's own doc block describes a rounded pressure hull and a dark canopy. 93.6% of what it draws is inside its own collision hull and none of it encloses anybody. | `_build_pod_airframe` | no | **nobody** |
| 5 | `train` | A red box on a black box, flat-fronted. FLAT 0.98. | `_build_train_body`, generic | no | `lane/train` |
| 6 | `tank` | Five road wheels where an M1 has seven -- a countable fault against a real vehicle. Hull and turret are otherwise the best-shaped of the four ground vehicles, FLAT 0.80. | `_build_tank_body`, generic | no | `lane/tank` |
| 7 | `airliner` | Slab-sided rectangular fuselage with a cone on the front, FLAT 0.97 and HULL 0.73 -- three quarters of its body is the collision box. The code at `vehicle_view.gd:1205` describes a "round pressurised fuselage, tapered at both ends". Deliberately unnamed, so there is no type to measure against -- but "generic" is a decision about *which* aeroplane, not a licence to draw a shed. | `_build_airliner_airframe` | no | **nobody** |
| 8 | `plane` | The same slab, smaller, with two nacelles. FLAT 0.97, HULL 0.51. | `_build_utility_twin_airframe` | no | **nobody** |
| 9 | `mercury` | **Measured and still not modelled.** `craft/mercury/sources.md` cites NAVAIR's 45.8 x 45.2 x 12.9 m and the model honours them to the metre, but the body between those numbers is the airliner's slab: FLAT 0.95, HULL 0.83. Getting the envelope right is not the same as drawing the aircraft. | `_build_mercury_airframe` | yes | **nobody** |
| 10 | `tanker` | Rounded lofted body and a correct high wing -- and **the tail assembly floats above and behind a fuselage that simply ends**. No boom, no tailcone. FLAT 0.33, which is why no measure in this file found it. | `_build_water_bomber_airframe` | yes | `lane/cl415` |
| 11 | `chinook` | Lofted round cargo body, which is right, and **no aft pylon** -- the rear rotor stands on empty air above the ramp. Rotors are flat planks. FLAT 0.09. | `ReferenceAirframeMeshes.fuselage`, TANDEM | yes | on the plan |
| 12 | `osprey` | Lofted body, tilting proprotors in the right places, **no nacelles** -- the rotors mount on bare wingtips. Tail fins are plain rectangular plates. FLAT 0.05, the best reading in the fleet. | TILTROTOR path | yes | on the plan |
| 13 | `uh60` | Its own 123-line airframe and a cited FM 3-04 envelope. The rear fuselage ends in a flat-cut cylinder and the tail rotor does not read at three-quarters. | `Uh60Airframe` | yes | **nobody** |
| 14 | `submarine` | Lofted tapered hull, correct sail position, masts. The sail itself is a plain rectangular box with square corners. | `ships/submarine.gd` | no | **nobody** |
| 15 | `boat` | Chamfered lofted hull and a good sheer line. The two deckhouses are open-topped boxes -- you can see down into them. | `ships/launch.gd` | no | **nobody** |
| 16 | `tower` | Was a bare concrete slab and **is fixed**: `d1b92370` drew the stalk, cab and roof at 13:01, two hours and nineteen minutes after the photograph that still shows a slab. It reads FLAT 0.99 because a stalk with a glass cab on it is honestly made of boxes -- the one place the measure cannot tell "never modelled" from "simple on purpose", and HULL 0.14 is what says it is not the collision hull. | `_build_tower` | no | done |
| 17 | `gunboat` | Lofted hull, glazed wheelhouse, rails, radar, masts. Nothing to fix by eye. | `ships/patrol_boat.gd` | no | — |
| 18 | `battleship` | Flared bow, tiered superstructure, funnels, turrets and barrels. One stray spar amidships is the only oddity. | `ships/battleship.gd` | no | — |
| 19 | `carrier` | Angled deck, island, deck markings, correct sheer. | `ships/carrier.gd` | no | — |
| 20 | `pirate` | Full brig rig with shaped sails and a lofted hull. | `brig/brig_rig.gd` | no | — |
| 21 | `glider` | **Done today.** `lane/glider` gave the already-tapered wing 3.07 degrees of dihedral and a winglet on each tip, replaced the single 0.88 m sphere with a 2.82 m tandem canopy lofted off the seat poses, and took off the anonymous 0.36 m gun dome `_build_turret` had been inventing -- which was the highest point on the aeroplane and was therefore the mesh satisfying DG's published 1.80 m height. | `_build_sailplane_airframe` | yes | done |
| 22 | `cessna` | Measured against the 172S information manual, 8.28 x 11.00 x 2.36 m, moving flaps, ailerons, elevators, trim tab, rudder and propeller. The only craft in the game whose `cabin_room()` says it encloses anybody. Its seats sit 1 m aft of and 0.45 m above the real ones, which moves in its own migration. | `SkyhawkAirframe`, 1,391 lines | yes | — |
| 23 | `gunship` | Tapered round fuselage, four six-blade turboprops, Hercules tail, gear, sponsons, at a measured 40.38 m span. | `_build_gunship_airframe` | yes | — |
| 24 | `fighter` | LEX, raked caret intakes, twin canted tails, tapered nose, at 2,234 faceted triangles. | `FighterAirframe`, 1,038 lines | yes | — |
| 25 | `hawkeye` | The reference. Rotodome, eight-blade props, folding wings, gear, measured envelope. | `HawkeyeAirframe`, 533 lines | yes | — |

### Nobody is working on any of these

`heli`, `segway`, `car`, `pod`, `airliner`, `plane`, `mercury`, `uh60`, `submarine`, `boat`.

**`heli` and `segway` are the two worst craft in the game on both measured columns** -- FLAT 0.97
and 1.00, HULL 0.89 and 0.99 -- and neither has ever been anybody's job. `heli` carries a
`sources.md` that says so in writing. `segway` is in no photograph, no roster and not in the
fidelity plan, because `craft_gallery_shot.gd` skips it "deliberately, because it has no visible
hull in that level"; it has no visible hull because it has never been drawn.

`car` and `pod` are next. `pod` is the one whose builder's doc block describes a rounded pressure
hull it does not draw.

## What this file got wrong on its first day

Three claims in the first version were wrong. All three came from reading a gallery photograph as
though it were evidence about the code, which is the exact failure this file was written to stop,
and two of them were caught by other lanes measuring rather than looking.

1. **"The train trails a steam plume a Super Chief never made, because a Super Chief was
   diesel."** False. `lane/train` checked: **nothing in `objects/vehicles/` emits a particle at
   all** -- no exhaust, no funnel, no smokestack on any vehicle in this game. The column is one of
   the island's ten fires, measured at **1,139 m** behind the locomotive and merely lined up with
   it by the camera. *A craft can look wrong because of something more than a kilometre behind
   it.*
2. **"The glider's wings are flat untapered planks of constant chord."** Half false. The wing was
   already tapered, 1.28 m at the root to 0.42 at the tip. **You cannot see chord taper on a 20 m
   wing from three-quarters front**, which is the only angle the gallery shoots. The real faults
   were no dihedral and no winglets, and `lane/glider` fixed both.
3. **A machine gun on a glider, in a picture I had open.** `_build_turret` invents an anonymous
   0.36 m gun dome on any craft with no turret seat. It is plainly visible in
   `cockpit-craft-glider.png` as a dark tube over the fuselage. I looked at that image and did not
   see it, because I was looking for boxiness. **A checklist decides what you can see.**

The lesson `lane/train` drew, which is the one to keep: **a claim about history needs evidence
from history.** The gallery tells you what a craft looks like from one angle at one moment; git
log tells you what somebody did to it. Neither alone is evidence, and this file's first version
used only the first.

## What the suite measures, and what it cannot

`tests/craft_model_audit` builds all twenty-five kinds through `preview_kind` and
`_show_in_editor()`, gathers every **visible** triangle into the craft's own frame from its drawn
vertices, and reports two fractions of the body -- the body being what lies inside the
simulation's collision extents, which the model did not choose. It ranks and shows. There is no
threshold anybody would have to defend, because **nobody has measured what number a good model
has**, and a limit nobody re-measured is how `ship_models` came to allow 250,000 triangles for a
ship that draws 1,396.

- **FLAT** -- how much of the body is drawn square to the craft's own axes. A craft nobody has
  modelled is a stack of slabs and reads near 1.00; a lofted body has no square faces to find.
- **HULL** -- how much of the body lies *on* the collision cuboid's own six faces. This is the
  simulation's box, re-rendered, with a boom and a rotor bolted to it.
- **shell** -- `VehicleView.cabin_room()`, asked and not answered again here.

Measured on `af1ca0e9`:

```
  #  craft         FLAT   HULL   body tris   of drawn   shell
  1  segway        1.00   0.99         974    59.6%   box
  2  tower         0.99   0.14       26076    75.4%   box
  3  train         0.98   0.09       30878    86.0%   box
  4  airliner      0.97   0.73       40138    71.3%   plates
  5  plane         0.97   0.51       25070    56.5%   plates
  6  heli          0.97   0.89       35226    59.6%   box
  7  mercury       0.95   0.83       30150    74.8%   plates
  8  car           0.93   0.11        9579    88.8%   box
  9  battleship    0.90   0.04        3302    62.6%   box
 10  carrier       0.85   0.27       13572    97.3%   box
 11  boat          0.85   0.40        4034    31.2%   box
 12  tank          0.80   0.01       22716    95.8%   box
 13  gunboat       0.77   0.65         910    43.7%   box
 14  submarine     0.53   0.52        1068    21.9%   box
 15  fighter       0.52   0.00        1146    28.3%   plates
 16  hawkeye       0.43   0.32       35006    21.4%   box
 17  pirate        0.43   0.07         477    38.8%   box
 18  cessna        0.41   0.00       16578    41.6%   encloses
 19  uh60          0.40   0.14       35404    75.0%   box
 20  tanker        0.33   0.00       37548    56.7%   box
 21  pod           0.31   0.01       39794    93.6%   box
 22  gunship       0.23   0.08       54938    54.2%   box
 23  glider        0.12   0.00       13420    41.9%   box
 24  chinook       0.09   0.03       46708    67.9%   box
 25  osprey        0.05   0.00       51508    43.8%   plates
```

### What the measure found that the eye did not

- **HULL names four craft that are literally the simulation's cuboid, re-rendered**: `segway`
  0.99, `heli` 0.89, `mercury` 0.83, `airliner` 0.73. Nothing about those bodies was drawn; the
  collision box was switched on and dressed.
- **The twenty-fifth craft.** `segway` is in no photograph and tops the table on both columns. It
  is in no gallery, no roster, and not in the fidelity plan.
- **The ships are slab-sided above the waterline.** `battleship` 0.90, `carrier` 0.85, `boat`
  0.85, `gunboat` 0.77, where the eye called all four finished. Their lofted hulls sit mostly
  *outside* the collision extents -- the submarine keeps 22% of its drawing as body, the boat 31%
  -- so what the body filter is left holding is the superstructure, and the superstructure really
  is a stack of boxes. Both halves are true and the number reports the second one. Read those four
  rows as "the deckhouses", not "the ship".
- **Faceting reads as flatness.** `fighter` 0.52 and `submarine` 0.53 sit higher than the eye
  would put them, because a low-poly faceted surface has many nearly-axis-aligned facets. That is
  the house look working as intended, and a reason FLAT is a ranking and not a score.

### What the measure cannot see, and this is the important part

**Every craft whose fault is a missing or misplaced part scores well.** The five faults a person
found by looking are invisible to both columns:

| Craft | FLAT | What is actually wrong |
|---|---:|---|
| `osprey` | 0.05 | proprotors mount on bare wingtips -- there are no nacelles |
| `chinook` | 0.09 | no aft pylon; the rear rotor stands on empty air |
| `tanker` | 0.33 | the tail floats above and behind a fuselage that simply ends |
| `pod` | 0.31 | no hull at all, where its builder's doc block promises one |
| `tank` | 0.80 | five road wheels where an M1 has seven |

Four of those five are in the best half of the table. **So there is no single number for this
question**, and a lane that replaced the looking with the measuring would have shipped an osprey
with no nacelles and called the fleet finished. The columns rank *how much of a craft was ever
shaped*; the eye finds *what is missing from the shape*; `cabin_room()` finds whether any of it
encloses the crew. All three are needed, and even all three missed a gun on a glider.

This is rule 2 of the workshop with a number attached: this game shipped bugs that were green in
every test, and it would have shipped five more that are green in this one.

## What this list says that a boxiness score would not

- **Eleven craft have never been measured against anything**: `heli`, `segway`, `car`, `pod`,
  `train`, `tank`, `airliner`, `plane`, `submarine`, `boat`, and `tower` before today's fix. Eight
  of those have no owner.
- **Four craft were measured and then drawn badly anyway** (`mercury`, `tanker`, `chinook`,
  `osprey`). These are the more valuable entries, because a cited source makes them look done in
  every roster that counts sources. `mercury` honours NAVAIR's envelope to the metre and fills it
  with the airliner's slab.
- **The four craft under remodel today** -- `tank`, `train`, `tanker`, `glider` -- come out at 6,
  5, 10 and 21 by eye and at 12, 3, 20 and 23 by measure. Neither list was built from the lane
  roster; both independently agree all four needed work, and both put the glider near the bottom
  of the fleet rather than the top. The suite holds that separation as a check: every craft with
  its own named airframe class must measure less slab-sided than every craft drawn by a generic
  builder, and the closest pair is `fighter` at 0.52 against `tank` at 0.80.

## What the existing roster gets wrong

`aircraft_model_fidelity_plan.md` carries a "Current gallery audit" table with a **Priority**
column numbered 1 to 12. It lists twelve kinds of twenty-five and omits every ground vehicle,
every ship, the pod, the segway and the tower. Its priority numbers were assigned once and have
not been re-derived since; `gunship` is priority 1 and is finished, `heli` is priority 9 and is
the simulation's box with a plank on top. That is the shape of a limit nobody re-measured. This
file is not a second roster: its two measured columns are printed by a suite on every run, and
the faults beside them name the craft and the part.

## Traps this pass had to avoid, and the one it did not

- **The gallery evidence is dated, and the date matters.** `cockpit-craft-tower.png` was written
  at 10:42; `d1b92370` drew the tower as a tower at 13:01. A list read off the pictures alone
  reports a fixed craft as broken, so the suite builds each craft rather than reading a PNG.
- **A cited source is not a model.** See `craft/heli/sources.md`, above.
- **A hidden mesh is not a drawn one.** `_hull` stays in the tree for every craft and is switched
  off for the tank, train, car, tower and pod, all of which draw a body of their own over it.
  Counting it would have scored five of the craft this list names a perfect 1.00 for a box nobody
  can see, flattering them into the middle of the table.
- **A fingerprint that mixes what was drawn with what the kind declares cannot notice that the
  wrong thing was drawn.** The distinctness check was sabotaged on purpose -- every row built as a
  Cessna -- and **it passed, with twenty-five distinct fingerprints**, because the fingerprint
  still carried `extents` and the body figures derived from it, which go on varying by kind while
  the aeroplane does not. It was proving that twenty-five kinds exist, which nobody doubted. Taken
  from the drawing alone it collapses to one fingerprint and fails.
- **A filter whose job is to exclude something cannot tell you it excluded everything.** With
  `BODY_REACH` mistyped small, every craft measures zero body triangles, every FLAT reads 0.00,
  and a table of twenty-five perfectly lofted aeroplanes prints `RESULT=PASS`. The check is held
  to both sides at once, against the glider's actual 20.0 m span rather than a percentage.
- **A craft's own self-report cannot see any of this.** Every model here is green in
  `fighter.gd`, `skyhawk.gd`, `fit.gd` and `stations.gd`, because each measures one half of a
  craft against the other half of the same craft.
- **And the one this pass walked into anyway**: reading a photograph as evidence about code.
  Three times. See "What this file got wrong on its first day".
