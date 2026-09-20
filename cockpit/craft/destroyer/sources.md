# destroyer — an Arleigh Burke Flight IIA

**The runtime exterior is an original procedural model.** It contains no downloaded mesh, texture, photograph,
trademark, marking or livery. It is haze grey with no pennant number, no name and no insignia: **the ship type, with one
real vessel as its dimensional reference.**

## The reference ship

**USS Oscar Austin (DDG-79)**, Bath Iron Works, commissioned 19 August 2000 — **the first Flight IIA**. Every dimension
is held to this one ship where it publishes one, and to the Flight IIA sub-class otherwise, **never to an average of the
class**. The flight matters visibly: Flight IIA is the first with the **two side-by-side helicopter hangars** aft and
the enlarged flight deck, and Flights I and II have neither.

## Authorities

| Id | What | Licence |
|---|---|---|
| S1 | https://en.wikipedia.org/wiki/Arleigh_Burke-class_destroyer (class infobox, per-flight rows) | CC BY-SA 4.0 text; facts only |
| S2 | https://en.wikipedia.org/wiki/USS_Oscar_Austin_(DDG-79) (ship infobox) | CC BY-SA 4.0 text; facts only |
| S3 | https://destroyerhistory.org/arleighburkeclass/flightiia/ | third-party; facts only |
| S4 | https://en.wikipedia.org/wiki/AN/SPY-1 (array size, deckhouse arrangement) | CC BY-SA 4.0 text; facts only |
| B4 | Commons `Arleigh Burke class destroyer Flight 1 line drawing.png`, 748×254, **orthographic**, **Flight I** | see Commons file page |
| B7 | Commons, port side view of **USS Lassen (DDG-82)**, builder's trials — **the broadside** | public domain, US Navy |

Photographs are for study only. Local copies and the full licence table are in
`~/godotgames-drafts/2026-09-17/cockpit-fleet3/research/burke/`, with the write-up in `research-burke.md` and the
re-derivation script in `measure_burke.py`.

**B7's Commons caption is wrong and the ship corrects it.** It is titled "Arleigh Burke **(Flight II)** Class ... USS
LASSEN (DDG 82)". DDG-82 is **Flight IIA**; the hangar and enlarged flight deck in the photograph settle it. Both names
are recorded here because **a mis-captioned source is unfindable by the correct search** — searching Commons for
"Flight IIA" never returns the best broadside available.

## The envelope

| Dimension | Value | Tag |
|---|---|---|
| Length overall | **155.30 m** (509 ft 6 in) | PUBLISHED [S1, S2, S3 agree] |
| Beam | **20.12 m** (66 ft) | PUBLISHED [S1, S2] |
| Length on the waterline | 143.56 m (471 ft) | PUBLISHED [S3] — **one source, so a claim** |
| **Moulded draught (the hull floats here)** | **6.63 m** | MEASURED [B4] |
| Sonar dome depth | 9.53 m | MEASURED [B4] |
| Freeboard at the stem | 8.59 m | MEASURED [B7] |
| Freeboard amidships | 5.87 m | MEASURED [B7] |
| Freeboard at the transom | 5.10 m | MEASURED [B7] |
| Masthead over the water | 45.29 m | MEASURED [B7] |
| SPY array face | 3.66 m octagon (12 ft) | PUBLISHED [S4] |
| Full load | 9,300 t | PUBLISHED [S2] — **a stated choice, see below** |

**Datum and axes:** x to starboard, y up from the design waterline, z aft. The origin is amidships on the waterline.

### THE PUBLISHED DRAUGHT IS NOT THE HULL'S DRAUGHT

**No source says which datum its 31 ft belongs to.** Measured off B4 with no hand picks — the waterline found as the
ink-heaviest row — the hull's bottom is **6.63 m** under the water and the sonar dome reaches **9.53 m**, against a
published **9.45 m**. The dome is **0.8 %** off the published figure; the hull bottom is **29.8 %** off. So 31 ft is a
**navigational draught to the bottom of the dome**, and **the model floats its hull at 6.63 m with the dome hanging
below it.**

**A hull drawn to 9.45 m would sit 2.9 m too deep and every size check would have passed**, because its bounding box
would have been right. `tests/merchant_models.gd` holds the two apart: the hull's own bottom amidships against 6.63 m,
and the deepest point anywhere against something more than a metre and a half deeper.

### Where the sources disagree, and what was chosen

**Full-load displacement, three sources, three numbers:** 9,500 long tons [S1, the class row], **9,200 long tons
[S2, the named ship]**, 9,157 long tons [S3]. A 3.7 % spread. The named ship's figure is used, because a number attached
to the ship beats one attached to its class. **There is no geometric route to settle this** — unlike the tanker's
freeboard, displacement cannot be read off a photograph — so it stays **a stated choice rather than a fact**.

## What the model deliberately does not do

No weapon, sensor or aircraft is a working system; the gun, the VLS cells and the arrays are shape only. There is no
helicopter, no wake, no navigation lights, no replenishment gear and no boats. The bridge is a room with seats, not a
reproduction of a real bridge layout, which is not public.

## OUTSTANDING REQUIREMENTS

**The SPY faces' cant is an ESTIMATE, and it is the most looked-at geometry on the ship.** It decides whether the model
reads as an Arleigh Burke or as a generic warship, and it is the one dimension here with no measurement behind it.

**Why it could not be measured, so nobody repeats the afternoon:**

1. **The published 3.66 m octagon cannot scale or measure itself.** A face on a canted corner is foreshortened
   **twice** — in width by the cant, in height by its rake — which is one observable against two unknowns. Measured on
   the bow-on view it read 147 × 92 px, an aspect of 0.63, which taken as rake alone is **51° from vertical**: absurd
   for a radar face, and that absurdity is what named the wrong assumption.
2. **It cannot be measured on the broadside either, where the scale IS known.** At 16.967 px/m the array is 62 px
   unforeshortened and about 44 px at a 45° cant, in a washed-out region where an array, a locker and a door look
   alike. **A feature you cannot identify cannot be measured, however good the scale is.**
3. **And a known vertical cannot be carried from the broadside onto the bow-on view** to scale it at the deckhouse:
   bow-on, the main deck there is hidden behind the forecastle and the only waterline on offer is at the **stem**, tens
   of metres nearer the camera. Sound in principle, and refused.

**What would satisfy it:** an **overhead or plan view**, or a close broadside of the deckhouse alone at a resolution
where the octagon's outline is unambiguous. Until one exists, `Destroyer.SPY_RAKE` and the deckhouse `CORNER` are
estimates and say so where they are declared.

**Also estimated**, and marked in the source: the deckhouse step heights, the hangar height, the funnel and mast
proportions, and where things sit along the ship. The 0.207 m-a-pixel line drawing cannot carry a 2 m deckhouse step,
and the broadside's superstructure is too low in contrast to read reliably.

## The measurement method, in one line

Scale from an orthographic drawing for everything under the water and from a beam-on photograph for everything above
it, with **the waterline fitted over five stations rather than taken from two ends** — the view is not exactly abeam,
and a waterline treated as one row put every height near the stern half a metre out in one direction, which **looks
exactly like sheer**.
