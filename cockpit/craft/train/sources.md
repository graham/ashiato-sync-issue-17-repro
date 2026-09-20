# The train: where its shape comes from

**The runtime train is an original procedural model.** It contains no downloaded mesh, no
photograph, no texture, no trademark and no livery artwork. Everything below is a public
dimension with its source, or a measurement taken off a public reference here, with the
method stated so it can be repeated or disputed.

Asked for on 2026-09-17: *"can you remodel the train to have this locomotive:
[Super Chief](https://en.wikipedia.org/wiki/Super_Chief) and
[Boxcar](https://en.wikipedia.org/wiki/Boxcar) for box cars, make trains 8-10 cars long."*

Every number carries a tag, and the tags mean what `modelling_here.md` section 3 says they
mean:

- **PUBLISHED** — a source states it, and the source is named.
- **MEASURED** — taken off a reference here. The method and the reference are named, and
  `measure_boxcar.py` re-derives it from the image alone.
- **ESTIMATE** — reasoned, no source. What it was reasoned from is stated.

---

## What stays authoritative whatever the model does

The simulation owns the train's origin, its collision extents, its mass, its four seat
poses, its devices and its replicated state — one distance along the railway and one speed.
`train_shape()` in `ashiato-gd/src/cockpit/cockpit_world.cpp` is where those live and the
model does not move any of them. **The boxcars are not in the simulation at all**: they are
drawn, hung off `rail_pose` behind the locomotive at a fixed spacing, and nothing can sit in
one. `cockpit/world/sky.gd`'s `_draw_carriages` is the whole of it, and it finds its
locomotives **by kind in `Sim.current`** — never by the id `spawn_train` returned, which is
the server's. The two worlds keep their own entity ids and nothing keeps the orders in step:
measured 2026-09-17, 82 vehicles on each side and the trains' ids two apart.

---

## The boxcar

### The reference

| | |
|---|---|
| File | Commons `RR77.96 Boxcar No. 5078 Side.JPG` |
| Subject | Philadelphia & Reading 5078, Railroad Museum of Pennsylvania |
| Size | 4928 × 2763 |
| Licence | **CC BY-SA 4.0**, Derek Ramsey (Ram-Man), self-photographed, 2015-06-07 |
| Why this one | **It is the only TRUE BROADSIDE of a boxcar on Commons.** Searched 2026-09-17. |

Kept for study in `~/godotgames-drafts/2026-09-17/cockpit-train/research/`, with the licence
table for every reference in `references.md` there. Nothing is incorporated.

### What the photograph settled, and what it could not

`cockpit/craft/train/measure_boxcar.py` re-derives all of this **from the image alone**, with
no figure typed out of this file, and writes an overlay of every fitted line onto the
photograph (`screenshots/2026-09-17/cockpit-train-06-...png`). Run it and argue with it.

| Quantity | Value | Tag |
|---|---|---|
| Roof line | fitted over 3,063 columns, **rms 2.3 px** | MEASURED |
| Side sill | fitted over 3,842 columns, **rms 2.5 px** | MEASURED |
| Body depth / length over the eaves | **0.2616** | MEASURED |
| Door opening / length | **0.1692** | MEASURED |
| Truck centres / length | **0.758** | MEASURED, ± about 4 % |
| Door's middle from the left end | 0.4663 of the length | MEASURED |

**IT COULD NOT GIVE THE RUNNING GEAR.** The wheels, the rails, the ballast and the car's own
shadow are all near black at this exposure and no threshold separates them. A first version
of the script fitted circles to what it took for wheel bottoms and **drew them in the grass,
twenty metres across**; the overlay caught it and no printed residual did. So the wheel's
diameter and the railhead are not measured here at all — they are the AAR standards below —
and the trucks' EXTENT is measured only in a narrow band just under the sill where nothing
else is dark. Even there the two trucks came out **56 % apart in length**, because the
outboard end of one runs into the coupler and the draft gear at the same black. That spread
is the uncertainty on the truck position and it is quoted rather than averaged away.

### The scale, and the two cross-checks nothing was fitted to

The car's class is not published anywhere an agent can read, so its length is the answer here
rather than the ruler. Everything above is a **ratio**, which needs no scale; the absolute
size comes from the published 40 ft class and this file says so rather than implying the
photograph settled it.

- **The door comes out at 7 ft 0 in.** It was measured as a fraction of the car's length and
  scaled by the class length, and a 40 ft boxcar was built with a **6 ft or a 7 ft** door and
  nothing else. Landing on one of the two, from a ratio and a published class, is evidence.
- **The truck centres come out at 31.3 ft** against a standard 30 ft for the class.
- **The roof lands under the loading gauge.** The MEASURED 3.30 m body depth plus an
  ESTIMATED 1.00 m sill height puts the eaves at 4.30 m, the ridge at 4.47 m and the running
  board's top at **4.53 m — 14 ft 10 in — against AAR clearance Plate B's 15 ft 1 in.** Two
  quantities that never saw each other, one measured and one assumed, add to a figure a
  published bound can judge, and it lands 6 cm inside it.
  `cockpit/tests/train_models.gd` holds the DRAWN height to that plate, and
  `cockpit/objects/vehicles/boxcar.gd` does not know the plate exists — which is the only
  reason that check can catch anything.

### The envelope the model is built to

| | Metres | Tag and source |
|---|---|---|
| Length over the eaves | **12.60** | ESTIMATE. 40 ft 6 in inside is PUBLISHED for the postwar AAR / Pullman-Standard 40 ft steel boxcar; over the eaves is that plus end framing and the roof's overhang, and no reachable source states it. |
| Length over the couplers | **13.48** | Computed: the length plus 0.44 m of coupler reach at each end. It **is** the spacing the level places cars at, so a rake has no gap and no overlap. |
| Width over the sides | **3.20** | ESTIMATE, 10 ft 6 in, inside the AAR plate's 10 ft 8 in. |
| Body depth, sill to eaves | **3.30** | MEASURED ratio × the class length. |
| Sill over the railhead | **1.00** | ESTIMATE, chosen so the ridge lands at a real extreme height under the plate (above). |
| Ridge over the eaves | **0.17** | ESTIMATE, a shallow peak from the reference's roof line. |
| Door opening | **2.13** | MEASURED ratio × the class length = 7 ft 0 in. |
| Truck centres | **9.55** | MEASURED ratio × the class length. |
| Truck wheelbase | **1.676** | PUBLISHED: 5 ft 6 in, the AAR / Bettendorf standard freight truck. |
| Wheel diameter | **0.838** | PUBLISHED: 33 in, the AAR standard freight wheel. |

The two PUBLISHED running-gear figures come from secondary sources quoting the AAR pattern
(spookshow.net's Bettendorf truck reference, and every model-railroad supplier's catalogue,
which agree). **The governing primary standard is AAR M-107/M-208 and it is not free**, so it
could not be read.

### Colour

Boxcar red. The reference car photographs at sRGB **(0.447, 0.266, 0.271)** under overcast,
which carries the sky's blue in it; the blue is taken back out and nothing else is changed,
giving **(0.43, 0.24, 0.20)**. The roof is a weathered galvanised **(0.235, 0.230, 0.225)** —
*darker* than the side, because a pale roof reads as a brim round the car from any angle
above it, and the first render had exactly that.

---

## The locomotive: an EMD SD40-2 (2026-09-19)

The user, 2026-09-19: *"can you use the methods you used to model the f16, f14 and other gold star examples to render a
new train locomotive"*, and then *"anything you find for a modern train will do"*. The F7A below stays on this page as
the record of what was learnt sourcing it; what the game draws is `objects/vehicles/road_diesel.gd`, an SD40-2.

**Why this type.** It is the most numerous heavy road diesel ever built in North America, it is a hood unit — which is
what a modern freight locomotive looks like — and, unlike an F-unit, it has BOTH a published envelope and photographs an
agent can read. The F7A had neither: there is no orthographic reference for a carbody unit anywhere on Commons.

### What is published

<https://en.wikipedia.org/wiki/EMD_SD40-2>, infobox, read 2026-09-19. Every one of these is PUBLISHED and typed into the
model and into `cockpit/tests/road_diesel.gd` separately, in the units the source prints:

| | |
|---|---|
| Length over couplers | 68 ft 10 in — **20.98 m** |
| Width over grabirons | 10 ft 3 1/8 in — **3.127 m** |
| Height | 15 ft 7 1/8 in — **4.753 m** |
| Truck (pivot) centres | 43 ft 6 in — **13.259 m** |
| Truck wheelbase, axle 1 to 3 | 13 ft 7 in — **4.140 m** |
| Wheel | 40 in — **1.016 m** |
| Trucks | HT-C, three axles each |
| Weight | 368,000 lb — **167,000 kg** |
| Prime mover, power | EMD 16-645E3, 3,000 hp |

### The references, and their licences

Kept for study in `~/godotgames-drafts/2026-09-19/cockpit-trains/research/`. **Nothing is incorporated**: the runtime
model is original procedural geometry containing no downloaded mesh, photograph, texture, trademark or livery.

| File | What it is | Licence | What it settled |
|---|---|---|---|
| `NS Loco No.3275.JPG` | NS 3275 at Elkhart, 3,648 × 2,736 | **CC BY-SA 3.0** / GFDL, "Railfan Jack" | The only TRUE BROADSIDE of an SD40-2 on Commons. Every longitudinal station and height aft of the cab front. |
| `Illinois Central Gulf 6045 (SD40-2)`, `6046` | ICG 6045 and 6046, 5,184 and 4,752 px | **CC0** | Three-quarter views of LOW-NOSE units: the nose's proportions against the cab, and nothing else — a three-quarter view has no scale. |
| `CNW 6847 head on September 2010.jpg` | CNW 6847 at the Illinois Railway Museum | **CC BY-SA 2.0**, H. Michael Miley | The cab front, the pilot and the nose seen end-on. |
| `CEFX 3133 ... SIDE VIEW ...jpg` | CEFX 3133 from above | **CC BY 4.0**, Paul Bungard | The roof: fans, stacks, and the real track it stands on. |

### What the broadside measured, and the two things it corrected

`ns3275` is fitted, not eyeballed: the walkway's white sill stripe is fitted over **1,757 columns at 3.5 px rms** and
runs **3,073 px** end to end. With the deck 19.90 m long — the published length over couplers less a coupler and its
pocket at each end, and **the softest number on this page** — that is **154.4 px a metre**, and then:

- the walkway stands **1.06 m** over the railhead. The model first typed 1.37, which would have put the long hood 5.06 m
  up, taller than the locomotive is published to be. It is built at **1.14**, because a 40 in wheel's top is 1.016 m up
  and the frame passes over it; the 8 cm is inside what the measurement is worth.
- the roofline runs flat at **4.70 to 4.79 m** over the whole hood and drops to **4.52–4.58 m** over the cab. **THE CAB
  ROOF IS BELOW THE LONG HOOD** on an EMD Dash-2, and the published 15 ft 7 1/8 in is the HOOD. The model had it the
  other way round, which reads as a switcher.

**The photographed unit is a HIGH SHORT HOOD SD40-2** — the Southern and N&W variant, whose short hood rises to the
hood line. Everything aft of the cab front is shared with a standard unit and is taken from it; the low nose is not, and
comes from the ICG and CNW references as a proportion.

### What could NOT be measured, and what would settle it

- **The running gear.** On the broadside the wheels, the truck frames, the rails and the locomotive's own shadow are one
  black at that exposure and no threshold separates them — the same trap the boxcar met in September. Two attempts at
  the truck frames' extents returned noise. So the trucks are the PUBLISHED figures and nothing is pretended otherwise.
  *What would settle it: an EMD outline diagram, or a broadside exposed for the shadows.*
- **The deck length**, on which the photograph's whole scale rests, is the published length over couplers less an
  assumed 0.54 m a coupler. *What would settle it: a published platform length, or a diagram.*
- **The nose's length and height** are proportions off three-quarter views, good to about 0.15 m.

### The livery

**No railroad's.** Every herald, name and paint scheme is a trademark. The locomotive wears the red the island's own
freight cars wear, with a black frame, a yellow sill stripe and a grey roof, and copies nobody.

---

## The F7A, and what sourcing it found (2026-09-17, superseded)

The drawn locomotive is still `VehicleView._build_train_body`'s generic hood unit. What the
sourcing found, so the next session does not repeat it:

### An EMD F7A is the Super Chief's Warbonnet silhouette

The Super Chief's power over its life was the EMC/EMD **E1** (1937), **E3**, **E6**, **FT**,
**F3**, **F7**, **FP45**, ALCO **PA** and **DL-107/108**, and FM Erie-builts
(<https://en.wikipedia.org/wiki/Super_Chief>). The **Warbonnet** was devised by **Leland
Knickerbocker** of the GM Art & Colour Section and first appeared on the E1 in 1937. The
F3/F7 A-B-B-A sets are the definitive image and the bulldog nose is what makes the
silhouette read instantly.

PUBLISHED, <https://en.wikipedia.org/wiki/EMD_F7> infobox:

| | |
|---|---|
| Length, A unit | 50 ft 8 in — **15.44 m** |
| Length, B unit | 50 ft 0 in — **15.24 m** |
| Width | 10 ft 7 in — **3.23 m** |
| Height | 15 ft 0 in — **4.57 m** |
| Wheel | 40 in — **1.016 m** |
| Wheelbase | 39 ft — **11.89 m** |
| Trucks | Blomberg B |
| Weight | 247,300 lb — **112,200 kg** |

### Three outstanding requirements, each with what would satisfy it

1. **THERE IS NO ORTHOGRAPHIC REFERENCE FOR AN F-UNIT** anywhere an agent can read. Searched
   2026-09-17: the whole of `Category:EMD F7 locomotives` (34 files, every one three-quarter);
   Commons searches for F3, F9, FP7, preserved units, museum roster shots and Santa Fe
   Warbonnet units; and **every SVG on Commons naming EMD** — of which the only drawing of a
   carbody unit, `EMD E-unit drawing.svg`, turns out to be a stylised three-quarter cartoon
   with gradients and a curved horizon. **And two references that look exactly like roster
   broadsides are PAINTINGS**: the Soo Line 200 and SP&S 800 "builder's portraits" by General
   Motors Electro-Motive are public-domain publicity *art*, square-on and 2.5:1, and are the
   references most likely to be mistaken for a measurable elevation. Nothing dimensional is
   taken from them. *What would satisfy it: an EMD outline or erecting diagram for the F3 or
   F7 — their exteriors are identical to the inch — a railway diagram-book page, or a genuine
   square-on photograph of a preserved unit with its running gear in daylight.*
2. **"Wheelbase 39 ft" has no stated datum.** On a B-B carbody unit it is normally the total
   wheelbase, axle 1 to axle 4, in which case the **truck centres** are 39 ft *less* the
   Blomberg truck's own wheelbase. The `Blomberg B` article publishes **no dimensions at
   all**, so the truck's wheelbase cannot be sourced, and the two readings put the trucks
   about 2.7 m apart from each other — which is exactly what a viewer sees. *What would
   satisfy it: the same diagram as above, or any dimensioned drawing of a Blomberg B.*
3. **The two Wikipedia articles disagree about width** — F7 says 10 ft 7 in, F3 says
   10 ft 8 in, on a carbody otherwise identical to the inch. One inch, 0.8 %, below anything
   the model will show; recorded rather than smoothed over. The F7's own 3.23 m is what a
   model of an F7 should use.

### The livery boundary

The Warbonnet's structure, read off Commons photographs of ATSF 315 (Galveston) and 347C
(Sacramento): the **nose face is yellow** with black pinstripes sweeping back and up; **red**
covers the nose sides, the cab and the upper body and steps down behind the cab; a **yellow
band with black edging** runs along the lower flank; the flanks below and behind are
**stainless/silver**; the pilot and underframe are silver-grey.

**The Santa Fe cross-in-circle herald and the "SANTA FE" lettering are trademarks and must
not be drawn.** The model is to carry the red / yellow / silver sweep as an original
interpretation of a well-known scheme, with no herald, no railroad name and no reporting
marks.

### And the fault to fix while remodelling it

`-Z` is forward everywhere in this game. `VehicleView._build_train_body` draws `TrainCab` at
**+5.22 m** — the *rear* — and `TrainFrontWindows` at +2.21 m, while the native shape puts
seats 0 and 1 at **−7.20 m**, the front. **Both drivers sit 12.4 m ahead of the cab they are
supposed to be in, inside the long hood, with the windscreen behind them.** Green in every
check; `screenshots/2026-09-17/cockpit-train-01-before-a-box-with-its-cab-at-the-back.png` is
the picture.

### And the size question the remodel has to answer

The native box is **18.00 m long, 3.10 wide, 4.00 tall**; an F7A is **15.44 × 3.23 × 4.57**.
That is 17 % too long, 4 % too narrow and 14 % too short, and it cannot be made to pass the
2 % drawn-bounds rule every other model here passes. `modelling_here.md` section 5 says that
where the research and the shape disagree, **the shape is wrong** — which makes this a C++
change to `train_shape()` plus a regeneration of `cockpit/craft/train/1`'s three hashes
through `cockpit/tools/generate_authored_packages.tscn`, not a number to type back into the
model. It is not this lane's to decide alone.
