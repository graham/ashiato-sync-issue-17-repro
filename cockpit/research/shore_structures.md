# The marina and the container terminal, and where their sizes come from

Both are original procedural models containing no downloaded mesh, photograph, texture,
trademark or livery. Neither copies a named real place: they are the TYPE of structure, and
what makes each of them the right size is not a photograph but **the things in this game that
use them**.

That is the whole idea of this file. An aeroplane gets its size from a three-view. A quay gets
its size from the ship that lies alongside it, a berth from the boat that lies in it, and a
helicopter pad from the machine that lands on it — and all three of those already exist in this
tree, measured, with their own sources. So almost nothing here is a figure taken off a drawing;
it is a figure **derived from another part of the game**, and the checks in
`tests/shore_structures.gd` ask whether the derivation actually landed.

---

## The helicopter pad, and the one place a published figure arbitrates

**CAP 437**, the UK CAA's *Standards for Offshore Helicopter Landing Areas*, defines the
**D-value** as the largest overall dimension of the helicopter with its rotors turning —
normally the most forward point of the main rotor's tip path to the most rearward point of the
tail rotor's — and requires the usable landing area to be at least **1.0 × D** across, with
**1.5 × D** preferred. ICAO Annex 14 Volume II carries the same idea onshore.

**The D-value is derived from the game's own Chinook.** `ChinookAirframe` declares hubs at
z −5.90 and +5.90 and a rotor 18.30 m across, because it has to draw itself; nothing about it
knows a helipad exists. Those give an overall dimension of

    5.90 + 5.90 + 18.30 = **30.10 m**

**and CAP 437's own table gives the CH-47 a D-value of 30 m.** Two figures that never saw each
other, 0.3 per cent apart. That is the arbitration `modelling_here.md` section 3 asks for, and it
is the reason the pad's size can be trusted rather than merely asserted — `shore_structures.gd`
holds the derived figure to the published one.

Everything else that may use these pads is smaller and is dominated rather than measured: the
Osprey is 25.77 m across its rotors (`OspreyAirframe.WIDTH`), the UH-60's rotor is 16.36 m, the
Little Bird's 8.35 m, and the F-35B is a 15.6 m aeroplane. A pad that takes a Chinook takes all
of them, which is why only the largest has to be got exactly right.

| | Across | Multiple | Why |
|---|---|---|---|
| Marina pad | 30.10 m | 1.0 × D | CAP 437's minimum; a marina is a cramped place |
| Terminal pad | 45.15 m | 1.5 × D | the preferred figure; a terminal has the room |

**And a pad is only usable if nothing hangs over it**, which no size check can see.
`_nothing_overhangs_either_pad` fires at the drawn triangles rather than the parts list — what
would actually hit a rotor is a vertex, not a box somebody reported — and requires nothing at all
between 0.5 m and 25 m over either slab. The terminal's pad is placed beyond the gantries'
landward backreach for that reason, and the marina's back from the pontoons and their masts.

---

## The container terminal, sized by the Triple-E

A ship-to-shore gantry has no size of its own. It is built to reach across the largest ship that
will lie under it, and every serious figure about it falls out of that ship — so `outreach()` and
`lift_height()` read `ContainerShipDraft.CLASSES["container_large"]` and nothing is typed.

| | Derived | From |
|---|---|---|
| Outreach | **62.50 m** | 3.5 m standoff + 22 gaps × 2.480 m + one 2.438 m box + 2 m to get the spreader outboard |
| Lift over the quay | **38.82 m** | ship's 14.0 m weather deck + 9 tiers × 2.591 m + 6 m spreader − 4.5 m quay |
| Dredged depth | 17.5 m | her published 16.0 m draught plus under-keel clearance |
| Rail gauge | 30.48 m | PUBLISHED, 100 ft — a property of the crane, not the ship |

**The published cross-check, and where it disagrees.** Super-post-Panamax cranes are described as
reaching "about 50 m", lifting "about 40 m", over **22** container rows, on a 100 ft gauge
([Wikipedia, *Container crane*](https://en.wikipedia.org/wiki/Container_crane)). The derivation
gives a longer reach than that, **and it should**: those figures describe cranes built for 22-row
ships, and a Triple-E is 23 rows and 58.6 m in the beam. A crane that reached 50 m could not work
this ship — which is exactly why the newest cranes are bigger than the ones that figure describes.
The lift height agrees closely (38.8 against "about 40"), and the rail gauge is taken from the
published figure rather than derived, because that one really is the crane's own.

The suite holds the crane from **both** sides: it must reach the outboard row, and it must not
reach more than 6 m past it. A crane twice the size it needs would pass the first check and be
absurd.

---

## The marina, sized by the boats in it

| | Derived | From |
|---|---|---|
| Finger berth length | **25.70 m** | the longest boat in `SmallCraftDraft` (the 22.50 m trawler) + 1.6 m slack each end |
| Berth width | **12.00 m** | the widest (7.90 m) + 1.6 m each side + a 0.9 m finger |
| Basin depth | 4.5 m ESTIMATE | the deepest boat draws 3.20 m |

Every one of those numbers moves if a boat is re-measured, which is the point.

**The breakwater is a shape question, not a size one.** A marina exists to be sheltered, so the
entrance must not look straight out to sea: the lee arm **overlaps** the seaward arm in the
along-shore direction, and a boat coming in passes the seaward head and turns. The first version
set the lee arm 24 m *past* the seaward arm's head, leaving a straight gap — a pair of walls with
a hole in them — and `_the_entrance_does_not_look_straight_out_to_sea` refused it. They overlap by
21.8 m now.

Section of the mound is an ESTIMATE from the usual 1-in-2 armour slope with a crest a lorry can
drive along; its footprint follows from the slope and the depth rather than being chosen.

---

## What is PUBLISHED, DERIVED and ESTIMATE

**PUBLISHED** — CAP 437's 1.0 × D minimum and 1.5 × D preferred, and its 30 m D-value for the
CH-47; the 100 ft crane rail gauge; the ISO 668 box the yard stacks.

**DERIVED** — the pad sizes, from the Chinook's own hubs and rotor; the crane's outreach and lift,
from the Triple-E's published rows, depth and draught; the berth length and width, from the small
craft's published lengths and beams; the mound's footprint, from its crest and slope.

**ESTIMATE** — the quay's height over the water and its dredged depth; the apron's width and the
berth's length along the quay; the number and spacing of cranes; the portal clearance, leg
sections, boom depth and backreach; the yard's tiers and lane widths; the basin's size and depth;
the breakwater's crest height and width; every building's footprint and height. None of these is
measured off anything, and they are the figures a reader should doubt first.

**Nothing here is MEASURED.** No drawing or scaled photograph of a terminal or a marina was used
at all, and that is stated plainly rather than left to be inferred — it is a weaker footing than
the container ships', whose turning circle came off a published table.

---

## Outstanding requirements

1. **Placement on a coast.** Both structures are built, proven and photographed, and **neither is
   yet placed in a level.** There is no "find the shoreline near here" helper in this tree:
   `Terrain.open_sea_near()` finds open water and nothing finds a shore with land behind it. The
   island's coast is a known line and fixed authored coordinates will work there; the generated
   ground needs a new search. This is written up as a todo.
2. **A general arrangement of a real terminal or marina**, which would replace most of the
   ESTIMATE list with measurements.
3. **The basin is not excavated.** A marina assumes water on its seaward side; it does not cut the
   terrain to make the water. Whatever places it has to put it on a coast that already has water
   there, and the gallery picture shows what happens when it does not — pontoons on grass.
