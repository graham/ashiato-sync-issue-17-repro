# Container ships visual reference — a feeder and a very large one

The runtime exteriors are original procedural models. They contain no downloaded mesh, photograph,
texture, trademark, funnel mark, operator's name or livery. Two ships of one type share this file
because they share one research effort and one box: the ISO container below is the same object on
both, and stating it twice is how the two would come to disagree.

Both are drawn as the ship TYPE with a named real vessel or published hull form as the dimensional
reference, exactly as `craft/crude_carrier/sources.md` uses MV Sirius Star. Neither carries the
colours or marks of the line that operates it.

---

## The two ships, and why these two

| | `container_feeder` | `container_large` |
|---|---|---|
| Reference | KRISO Container Ship (KCS), 3,600 TEU | Maersk Triple-E (Mc-Kinney Møller class), 18,270 TEU |
| Length | 230.0 m Lpp PUBLISHED, 235.0 m LOA ESTIMATE | 399.2 m LOA PUBLISHED |
| Beam | 32.20 m PUBLISHED | 58.6 m PUBLISHED |
| Draught | 10.80 m PUBLISHED | 16.0 m PUBLISHED |
| Depth to main deck | 19.0 m ESTIMATE | 30.0 m ESTIMATE |
| Block coefficient | 0.651 PUBLISHED | not published |
| Service speed | 24 kn PUBLISHED | 16 kn design, 19 kn optimum, 23 kn max PUBLISHED |
| Rows across, on deck | 13 DERIVED | 23 PUBLISHED, and 24 DERIVED |
| Tactical diameter | **3.16 L MEASURED** | ESTIMATE, bounded below |
| House | aft, over the engine room | **forward of midships, engine and funnel aft** |

They were chosen to be different ships rather than one ship at two sizes. The feeder is the
conventional arrangement — everything aft, one island — and the large one is the two-island
arrangement that makes a Triple-E recognisable at a glance: the accommodation block stands well
forward and the engine casing and funnel stand a long way abaft it, with the container bays running
between and around them. A reader who cannot tell them apart in silhouette has been failed by the
model.

### The feeder's reference is a published hull form, not a ship afloat

The KCS is a 3,600 TEU container ship designed at the Korea Research Institute of Ships and Ocean
Engineering as an open benchmark for hydrodynamic validation. **No full-scale ship was ever built.**
That is stated here in as many words because it is the kind of thing a later reader will otherwise
assume: the hull form, its dimensions and its manoeuvring are public and measured, and the vessel
is not. It was chosen for exactly that reason — it is the only container ship in the 200–260 m band
whose turning circle has been measured and published where an agent can read it, and the user asked
for turn radius from public sources.

Sources: [SIMMAN / FORCE Technology's KCS pages](http://www.simman2008.dk/KCS/kcs_geometry.htm) and
the NMRI Gothenburg-2000 workshop page. **`simman2008.dk` cannot be fetched by an agent**: it
answers with a certificate whose altnames are `forcetechnology.com`, so the hostname does not match
and the fetch is refused before any content arrives. This is a different failure from the 403s
`modelling_here.md` section 2 lists and it is recorded here so the next lane does not spend the
attempt. The particulars below were taken instead from the model table of a paper that states its
scale factor, which is a stronger reading anyway — see the next section.

### The large one's reference

The Maersk Triple-E class, built by Daewoo Shipbuilding & Marine Engineering, first delivery
2 July 2013. [Wikipedia's article](https://en.wikipedia.org/wiki/Triple_E-class_container_ship)
gives the particulars used here. The **23 rows of containers across the deck** are published there
and are the single most useful number on the page, because they are a direct statement about the
thing the model has to draw.

---

## The container, which is exact

ISO 668 fixes the box, and a container ship drawn with the wrong box reads wrong to anybody who has
seen one. These are not measurements and not estimates; they are definitions, and they are typed as
constants once:

| | Length | Width | Height |
|---|---|---|---|
| 20 ft (1CC/1C) | 6.058 m | 2.438 m | 2.591 m |
| 40 ft (1AA/1A) | 12.192 m | 2.438 m | 2.591 m |
| 40 ft high cube (1AAA) | 12.192 m | 2.438 m | 2.896 m |

**The rows across the deck were going to be DERIVED from the beam and the box, and that was wrong.**
It is recorded here as it happened, because the correction is the useful part:

- Feeder: 32.20 / 2.438 = **13.21**, so **13 rows**. That is the classic Panamax figure and it
  follows from the canal's 32.31 m lock width, which is where the beam came from in the first
  place. Derivation and practice agree here.
- Triple-E: 58.6 / 2.438 = **24.03**, so twenty-four boxes fit across the beam with 7 cm to spare.
  **Maersk publishes twenty-three.** The derivation is not wrong about geometry and is wrong about
  the ship: the missing row is the lashing-bridge walkway, and a hull's beam cannot tell you a ship
  chooses to give up 2.53 m of deck to it.

So **`rows` is a figure in the class table — PUBLISHED where a source states it, derived only where
the two agree — and the derivation survives as a sanity bound**: a ship may not carry more rows than
physically fit. `merchant_models` holds both, and the bound is slack on the Triple-E (23 drawn, 24
would fit) exactly where the disagreement lives.

**What the box size does cross-check is the gap between the stacks.** Thirteen ISO boxes are
13 × 2.438 = 31.694 m, so in a 32.20 m Panamax beam the twelve gaps between them share 0.506 m and
each is **0.042 m**. That is the lashing clearance, derived rather than guessed — and it matters,
because a first pass guessed 0.10 m, which makes thirteen rows want 32.89 m of a 32.20 m beam and
drew twelve. The model now draws 13 rows occupying **exactly 32.20 m** of a 32.20 m beam. A gap
guessed at a round number is a gap that quietly decides the cargo.

---

## The turning circle, which is the user's ask

**The measurement.** Kim, Tezdogan et al., *Free running CFD simulations to investigate ship
manoeuvrability in waves*, Ocean Engineering 2021, open access at
[Strathprints 77222](https://strathprints.strath.ac.uk/77222/), simulates the standard 35° turning
circle on the KCS and compares it against the experiment of Yasukawa et al. (2021). Its Table 7,
calm water, model scale 1:75.24, model Lpp 3.057 m:

| | CFD | EFD (measured) | in ship lengths, from EFD |
|---|---|---|---|
| Advance | 9.30 m | 9.29 m | **3.04 L** |
| Transfer | 3.95 m | 4.16 m | **1.36 L** |
| Tactical diameter | 9.94 m | 9.66 m | **3.16 L** |
| Time to 90° | 15.45 s | 15.64 s | — |
| Time to 180° | 31.50 s | 30.50 s | — |

Approach speed 14.5 kn full scale, 35° of rudder to starboard, deep water, full draught.
Full scale that is a tactical diameter of 3.16 × 230.0 = **727 m**, and a 180° turn taking
30.50 × √75.24 = **265 s**.

**How that table was read, because it does not read cleanly.** `pdftotext -layout` shifts the
columns: the rows come out as `Advance () 9.30 10.40 0.01`, which is not three values of one
quantity. The error column is what reconstructs it — every row checks to two decimal places once
the CFD and EFD values are paired correctly (RPS 10.56 v 10.40 → 1.54 % against a printed 1.58;
advance 9.30 v 9.29 → 0.01 % against 0.01; tactical diameter 9.94 v 9.66 → 2.90 % against 2.89;
time to 180° 31.50 v 30.50 → 3.28 % against 3.28). Five rows agreeing to the second decimal is not
a coincidence, and it is the reason these numbers are tagged MEASURED rather than "read off a
table". **Anyone disputing them should re-derive the pairing from the error column, not re-read the
PDF.**

**And the scale confirms the ship.** The paper's Table 1 is a MODEL table: Lpp 3.057 m, beam at
waterline 0.4280 m, draught 0.1435 m, Cb 0.651, at a stated 1:75.24. Multiplied out those give
**230.0 m, 32.20 m and 10.80 m** — the KCS's published full-scale particulars, to four figures. So
the turning circle above belongs to the ship this model is drawn as, and that was checked rather
than assumed.

**The independent bound.** IMO resolution
[MSC.137(76)](https://wwwcdn.imo.org/localresources/en/KnowledgeCentre/IndexofIMOResolutions/MSCResolutions/MSC.137(76).pdf),
*Standards for Ship Manoeuvrability*, requires tactical diameter not to exceed **5 ship lengths**
and advance not to exceed **4.5**. The measured 3.16 L and 3.04 L sit inside both with room. Two
sources that never saw each other, agreeing on a third quantity.

**The large ship's turn is an ESTIMATE and is tagged so.** No published tactical diameter for a
Triple-E, or for any ULCV, could be found that an agent can read; a manoeuvring booklet or a
sea-trial report is what would settle it, and that is the outstanding requirement. Until then the
model records the IMO ceiling of 5 L as the bound and 3.5 L as the working figure, reasoned from
the KCS's measured 3.16 L and the fact that a fuller, larger hull with a single rudder turns wider
rather than tighter. **This is the figure on the ship carrying the least evidence, and it is the
one a reader will quote.** Do not let it become PUBLISHED by being copied.

---

## What is MEASURED, what is PUBLISHED and what is an ESTIMATE

**PUBLISHED** — Triple-E: length overall, beam, draught, TEU, rows across the deck, design and
maximum speed, installed power, builder, delivery. Feeder: Lpp, beam at waterline, draught, block
coefficient, service speed, TEU.

**MEASURED** — the feeder's turning circle (advance, transfer, tactical diameter, times to 90° and
180°), off the Ocean Engineering Table 7 above by reconstructing its column shift from its own error
column; good to the second decimal in the non-dimensional figures.

**DERIVED** — rows of containers across each ship, from the published beam and the ISO 668 box
width; checked against the published 23 on the Triple-E.

**ESTIMATE** — the feeder's LOA (235.0 m, Lpp + 2.2 %, the ratio comparable Panamax box ships
carry; the KCS has no published LOA because it was never built). Both depths to the main deck
(19.0 m and 30.0 m), reasoned from a depth-to-draught ratio near 1.76 and 1.88, which is the band
container ships of these draughts sit in; neither is published where it can be read. The large
ship's tactical diameter, as set out above. The fore-and-aft lengths of both houses, the funnel and
the engine casing: no drawing looks at them square.

**Datum and axes:** origin midships on the design waterline, forward −Z, up +Y, starboard +X,
1 unit = 1 m, as every ship here. The simulation's parts stay authoritative for size, collision and
seats; the model draws them.

---

## Outstanding requirements

Written down with what would satisfy each, per `modelling_here.md` section 3 — a stated gap with
its remedy is a finding, an invented number in the same place is a liability.

1. **A published tactical diameter for a ULCV.** Wants a manoeuvring booklet, a wheelhouse poster
   photographed legibly, or a sea-trial report. Would replace the large ship's 3.5 L ESTIMATE.
2. **Depth to the main deck for either ship.** Wants a general-arrangement drawing or a class
   register entry. Both are currently reasoned from ratios.
3. **The feeder's LOA.** Cannot exist for the KCS, which was never built; if the feeder is ever
   re-referenced to a real ship, this goes away rather than being satisfied.
4. **`simman2008.dk` is unreadable by an agent** (certificate altname mismatch, not a 403). If the
   KCS particulars are ever wanted first-hand, that host needs a human or a different mirror.
