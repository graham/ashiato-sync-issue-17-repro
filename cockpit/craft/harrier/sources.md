# McDonnell Douglas / BAe AV-8B Harrier II visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/harrier_airframe.gd`). It contains no downloaded mesh, photograph, texture, trademark or livery.

**It is the AV-8B Harrier II Night Attack**, the second-generation aeroplane: the shoulder-mounted supercritical wing
with 11 degrees of ANHEDRAL and its leading-edge root extensions, the raised cockpit, the four vectoring nozzles, the
bicycle undercarriage with **mid-span** outriggers, the LIDS strakes and fence under the belly, and the
reaction-control jets at nose, tailcone and wingtips. It is not a first-generation GR1/AV-8A (smaller wing, no LERX,
**outriggers at the wingtips**) and it is not an AV-8B Harrier II Plus (an APG-65 radar in a nose 1.42 ft longer).

---

## 1. The authority for the shape

**[SAC]** **NAVAIR 00-110AV8-4, *Standard Aircraft Characteristics: AV-8B Harrier II*, McDonnell Douglas, October
1986**, 19 pp. This is the primary source and every SHAPE figure below is off it. Page 2, "DESCRIPTIVE AND
ARRANGEMENT", is a dimensioned orthographic three-view with its own printed `SCALE IN FEET` bar; page 3 carries the
DIMENSIONS, POWER PLANT and WEIGHTS tables. It is the same document class `lane/prowler` measured the EA-6B from
(`craft/prowler/measure_sac.py`), and it is to be read the same way.

Recovered from the Internet Archive (the alternatewars.com original is now a parked domain). **19 pages, every one a
scanned raster with no text layer** — so nothing can be grepped out of it and every figure here was read off the
rendered page by eye and is recorded with its page number.

> **The reproduction notice, recorded rather than glossed.** Page A carries: *"Reproduction for non-military use of the
> information or illustrations contained in this publication is not permitted without specific approval of the issuing
> service (NAVAIR or USAF)."* **No illustration, pixel or scan from it is incorporated into this game.** What is used
> is measured dimensions of an aeroplane — facts about the aircraft, not the publication's artwork — exactly as
> `lane/prowler` used the EA-6B's sheet. The scan lives in `~/godotgames-drafts/`, never in the repository.

**[NATOPS]** `A1-AV8BB-NFM-000`, *NATOPS Flight Manual, Navy Model AV-8B/TAV-8B Aircraft, 161573 and Up*, Naval Air
Systems Command, 714 pp, **with its text layer intact** so it is searchable. **Public domain** as a US Government
work. Used for the nozzle stops, the reaction controls, the control-surface travels and the airspeed limits, and as an
independent check on [SAC]'s dimensions.

**[WP]** Wikipedia, "McDonnell Douglas AV-8B Harrier II" and "Rolls-Royce Pegasus". CC BY-SA, quoted for figures only.
Used for the later **F402-RR-408** engine and its weights, and for the Pegasus's internals. **Where it disagrees with
[SAC], [SAC] wins** — see section 3.

**Rejected, and recorded so nobody hunts for it twice:** `McDonnell Douglas AV-8B Harrier II 3-view line drawing.png`
on Commons (public domain, US Army) is **574 × 385 px**, about 28 px a metre, so nothing off it is better than 3.5 cm
— against the F-35B renders' 5.6 mm a pixel. The Commons title `McDONNELL DOUGLAS, BAe AV-8B HARRIER II.png` that
[WP]'s infobox cites **redirects to that same file**; it is not a second, better drawing.

---

## 2. Why this variant, and why that matters

`modelling_here.md` section 3: **scale a drawing by the variant it actually depicts.** [NATOPS] para 1.2 prints both
lengths, and they differ by 3.1 per cent of the whole aeroplane:

> Length — AV--8B **46.33 feet** · AV--8B (Radar) **47.75 feet** · TAV--8B 50.53 feet

[SAC] and [WP] both give **46.33 ft**, which is [NATOPS]'s plain `AV-8B` row to the inch. **Three sources agreeing on a
figure none was set from** establishes that all of them describe the non-radar aeroplane and may be used together. Had
the model been called "AV-8B Plus" and built to these numbers, every dimension would have been stretched 3.1 per cent,
silently and in one direction.

**The day-attack and night-attack airframes are dimensionally identical** — [NATOPS] prints one row covering both, and
[NATOPS] Figure 1-1 draws one general arrangement for both, labelling only the FLIR sensor "(NIGHT ATTACK)". So [SAC]'s
1986 day-attack drawing is a sound reference for the night-attack shape, and the FLIR fairing is the single extra part.

**The engine is NOT common, and that is stated rather than blurred.** [SAC] is the early aeroplane with the
**F402-RR-406**; the Night Attack has the **-408**. Shape comes from [SAC]; thrust and the weights that go with it come
from [WP]'s -408 block. Both are named at the point of use.

---

## 3. The envelope, PUBLISHED

### [SAC] page 3, DIMENSIONS — the authority

| | printed | metres |
|---|---|---|
| Wing area | **230 sq ft** | **21.368 m²** |
| Wing span | **30.33 ft** | **9.245** |
| M.A.C. | **8.32 ft** | **2.536** |
| **Sweepback (25% chord) (projected)** | **30.62°** | |
| **Incidence** | **3°** | |
| **Dihedral** | **−11°** (anhedral) | |
| Length | **46.33 ft** | **14.122** |
| Height | **11.65 ft** | **3.551** |
| Wheelbase (nose to main) | **11.42 ft** | **3.481** |
| **Tread (outrigger)** | **17.0 ft** | **5.182** |
| MLG tyres | **26 × 7.75 in** | 0.660 dia |
| NLG tyre | **26 × 8.75 in** | 0.660 dia |
| **Outrigger tyres** | **13.5 × 6.0 in** | **0.343 dia** |

[SAC] page 2's three-view prints span 30.33 FT, tread 17.00 FT, length 46.33 FT, height 11.65 FT, wheelbase 11.42 FT
and **tailplane span 13.93 FT (4.246 m)**, so the drawing and the table agree and the drawing can be scaled by either.

**[NATOPS] para 1.2 confirms four of them independently**: span 30.33 ft, length 46.33 ft, height (top of fin) 11.65
ft, and "Wing gear spread — All — **17 feet**". Two documents, no shared derivation.

**THE WING AREA IS A REAL DISAGREEMENT, and arithmetic settles it.** [WP] gives 243.4 sq ft. [SAC] gives 230.0 sq ft
**and prints its own aspect ratio, 4.0**, on the same page — and 30.33² / 230.0 = **4.00**, so [SAC]'s span, area and
aspect ratio are internally consistent. [WP]'s 243.4 against the same span gives 3.78, which is not the printed aspect
ratio. **[SAC] is used; [WP]'s figure is recorded here and not believed.** (`modelling_here.md` section 2: a single
source is a claim, not a fact.)

### The outriggers are mid-span, and this is the II's signature on the ground

17.0 ft of tread across a 30.33 ft span puts each outrigger **2.591 m out, 56.0 per cent of the 4.623 m semi-span** —
well inboard of the tip. [SAC] page 3's own text says where and why:

> "The landing gear consists of a nose gear and a single main gear mounted in bicycle or tandem arrangement and two
> outrigger gear located **approximately mid-span on each wing between the flap and aileron**."

A model with wingtip outriggers is a first-generation Harrier. The check holds the drawn outrigger tyres 5.182 m apart,
which is a PUBLISHED number and not one measured here.

### THE AEROPLANE PARKS NOSE-UP, 6.5 degrees

[SAC] page 2's side view **draws the aeroplane level and rakes the GROUND LINE, marked 6.5°.** This is exactly the trap
`modelling_here.md` section 5 names — *"A Standard Aircraft Characteristics side view will often draw the aeroplane
LEVEL and rake the GROUND LINE instead, and reading it the other way silently levels an aeroplane that is not level"* —
met on the EA-6B at 5.8°. So the Harrier is built on `ProwlerAirframe`'s machinery (a measured `GEAR_RAKE`, a
`ground_at(station)` returning a raked plane, and a check asserting the tyre bottoms DIFFER), never on the Hawkeye's
level-tyres convention.

**It arrives by a second road**, which is what makes it more than a printed angle: [NATOPS] p96 says the fuselage sits
about **6½° nose-up at the hover stop**, and the hover stop is **82° from the engine datum** — so 82 + 6.5 = 88.5
degrees from the horizontal, very nearly vertical, which is what a hover requires. The parked rake, the hover attitude
and the nozzle stop are three published numbers that agree with each other and with physics.

**Still to be confirmed by measurement, not taken on trust** (`lane/prowler` checked its rake three ways): the lower
common tangent to the two tyre circles fitted off [SAC] page 2, against the printed 6.5°.

### The nozzles, PUBLISHED

[SAC] page 3, POWER PLANT: **"Nozzle rotation angles — Front 0° to 98.5° · Rear 0° to 98.5°"**. Both pairs, the same
range, which is why they are described as synchronised.

[NATOPS] p96 gives the detents the pilot actually uses, and they are richer than the F-35B's single lever:

| stop | angle from the engine datum | what it is |
|---|---|---|
| aft | **0°** | wingborne flight |
| STO stop | **35° to 75°, selectable in 5° steps** | the short take-off preset, set on the ground and slammed to at rotation |
| hover stop | **82°** | the hover |
| **braking stop** | **98.5°** | *"can be selected by lifting the nozzle lever over the hover stop and pulling it back along a ramp"* |

[PEG] adds the internals: the front nozzles are steel, fed with LP-compressor air; **the rear are Nimonic with hot
(650 °C) jet exhaust; the airflow split is about 60/40 front/back**; and all four are turned by motorcycle chains
driven by air motors. **Two cold plumes forward and two hot ones aft is a fact about the aeroplane**, and it is why the
exhaust is drawn with two temperatures.

### Power and weights

[SAC] page 3, F402-RR-406, uninstalled static thrust at sea level, *"\*Includes splay loss (90° nozzle rotation)"* — so
these already are the lift-mode figures:

| setting | lb | % RPM |
|---|---|---|
| Short lift wet (15 sec) | **21,550** | 107.0 |
| Normal lift wet (1.5 min) | 20,780 | 104.5 |
| Short lift dry (15 sec) | **20,280** | 103.5 |
| Normal lift dry (2.5 min) | 19,380 | 100.5 |
| Combat (10 min) | 18,720 | 99.0 |
| Maximum continuous | 14,540 | 91.0 |

Augmentation is **water injection**, 60 US gal at 330 PPM — which is what the water tank in [NATOPS] Figure 1-1 is, and
why there is a wet rating and a dry one. Engine length including nozzles **137.3 in (3.487 m)**, inlet diameter 48.05 in.

[SAC] weights, lb: empty 12,835 · operating 13,086 · **maximum take-off 31,000** · maximum landing 25,000.

[WP], for the **-408** aeroplane this model is: thrust **23,500 lbf (105 kN)**; empty 13,968 lb (6,340 kg); **maximum
take-off, rolling 31,000 lb (14,100 kg)**; **maximum take-off, vertical 20,755 lb (9,415 kg)**.

**The hover margin, cross-checked.** `modelling_here.md` section 3 asks for a third quantity neither figure was set to
produce. Thrust against the two take-off limits gives one:

- 105 kN against the **vertical** limit of 9,415 kg = **1.137 g**. It hovers, with 14 per cent in hand.
- 105 kN against the **rolling** limit of 14,100 kg = **0.76 g**. It cannot lift that vertically at all.

Neither was derived from the other, and together they say exactly why the aeroplane has a rolling take-off and why the
ski jump exists. (The F-35B's equivalent margin is 1.08.) The handling's `hover + collective_range` is **computed from
those two published figures**, never typed beside them.

### Limits and travels

- [NATOPS] pp26, 48, 217, 220: **585 KCAS / 1.0 IMN** for the AV-8B; flaps STOL 300 kt, CRUISE 0.87 Mach; **gear
  operating 250 kt**. [WP] gives Mach 0.9 against [NATOPS]'s 1.0 IMN — recorded; the 585 kt agrees exactly.
- [NATOPS] pp122-124: **stabilator travel about 10° trailing-edge up and 11° down**; **"Rudder travel is 15° right and
  left."** The reaction controls are bleed-air shutter valves off the HP compressor behind a master butterfly valve,
  and they lose effectiveness as airspeed rises.
- [NATOPS] p269: maximum nosewheel steering angle **45°**; low-gain steering gives about a **90 ft** turn radius at the
  centre of gravity.
- [SAC] load factors: basic 7.0 · design 5.4 · combat 7.6 · maximum take-off 5.3.

---

## 4. The features that make it a Harrier, PUBLISHED

[SAC] page 3's own description, quoted because every clause is a part to draw:

> "The AV-8B has a **raised cockpit with wraparound windshield** and a **shoulder mounted, swept wing with
> marked-negative dihedral**. The wing includes a **large, single slotted flap, drooped ailerons** in the high lift
> configuration, and a **Leading Edge Root eXtension (LERX)**. Conventional aerodynamic controls are used in wingborne
> flight and **engine bleed air reaction controls** are used in jetborne flight with a mix of two systems being used
> when transitioning between modes of flight. ... **two side inlets and four exhaust nozzles** ... **Lift Improvement
> Devices (LIDS) consisting of two longitudinal strakes and a retractable forward fence mounted on the lower fuselage
> between the nose and main gear**, are provided to improve performance in vertical takeoff or landing. The
> hydraulically operated **speedbrake** is located on the lower fuselage surface immediately aft of the main landing
> gear."

And: "**Fuselage strakes are interchangeable with the gun and ammo pack**" — so the LIDS strakes and the gun pods
occupy the same two places, one or the other. "Stencil **SJU-4/A ejection seat**." "The wing, forward fuselage and
stabilator are fabricated of composite structure."

**LIDS is the part worth naming twice.** Two strakes and a retractable fence whose entire purpose is to trap the
fountain of air rebounding off the ground in the hover. It is a moving part that exists *because of* the effect this
lane is also building, and nothing else in this game has anything like it.

### The reaction controls, PUBLISHED

[NATOPS] Figure 1-1 names all four and where they sit — the authority for the layout, rather than a photograph:

| as the drawing labels it | where | axis |
|---|---|---|
| FORWARD PITCH REACTION CONTROL NOZZLE | under the nose, ahead of the cockpit | pitch |
| AFT PITCH/YAW REACTION CONTROL NOZZLE | the tailcone, under and beside the fin | pitch and yaw |
| ROLL REACTION CONTROL NOZZLE | one under each wingtip | roll |

[NATOPS] 1.1.1, the sentence the aeroplane hangs on: **"Four exhaust nozzles can be positioned and controlled for
vertical/short takeoff and landing (V/STOL) operation."**

---

## 5. Research files and licences

All under `~/godotgames-drafts/2026-09-19/cockpit-harrier/research/`, with `FETCH-LOG.txt` recording every URL tried.
**None is incorporated into the game.**

| file | source | licence | used for |
|---|---|---|---|
| `sac-AV-8B-1986.pdf`, `sac-page-1..19.png` | NAVAIR 00-110AV8-4, Oct 1986, via the Internet Archive | US Gov work; **carries a non-military reproduction notice, quoted in §1** | **every shape figure**; measured, never reproduced |
| `natops-AV-8B-000.pdf` + page dumps | NAVAIR A1-AV8BB-NFM-000, via publicintelligence.net | public domain (US Gov) | nozzle stops, RCS layout, travels, limits |
| `commons-3view.png` / `commons-ortho.png` | Commons, US Army, byte-identical | public domain | **NOT USED — 574 × 385 px.** Recorded so nobody hunts for it twice |
| `wikipedia-av8b.txt`, `wikipedia-pegasus.txt` | Wikipedia wikitext | CC BY-SA | [WP], [PEG] |
| `nasa-ground-effect-20020063498.pdf` | NASA, *Parametric Study of a YAV-8B Harrier in Ground Effect* | public domain (NASA) | the fountain and hot-gas reingestion the exhaust draws |
| `nasa-aero-model-TM88376.pdf` | NASA TM 88376, *Full-Envelope Aerodynamic Modeling of the Harrier* | public domain (NASA) | offered to flightcore; not used here |
| `nasa-rcs.pdf` | NASA TM 104021, *YAV-8B Reaction Control System Bleed and Control Power* | public domain (NASA) | the RCS, if the scan can be read |

---

### The photographs, 2026-09-20 — Commons and Wikipedia only, READ FOR SHAPE ONLY

All under `~/godotgames-drafts/2026-09-20/harriernozzle/research/`, with its own `FETCH-LOG.txt`
recording every URL tried, each file's sha256, and the full Commons metadata, plus `manifest.json`.
Fetched by direct HTTPS GET with team-lead's approval, **never into the repository**.
**Nothing here is traced, incorporated, or used as a texture.** What is used is measured dimensions of
an aeroplane — facts about the aircraft, not the photographers' work — exactly as §1 says of [SAC].

They exist because **[SAC] cannot resolve a nozzle**: at 15.9 mm a pixel each is a blob tangled with the
wing root, the gun pod and the gear, and `lane/harrierlook` read it run by run and found the only closed
shape there is the gear door. The beam-on frame is 3.2 mm a pixel. `craft/harrier/measure_photos.py`
re-derives every figure below from the images alone and reads nothing out of this file.

| file | Commons title | author | licence | used for |
|---|---|---|---|---|
| `beam-side-yuma.jpg` | McDD AV-8B Harrier II '163867 - KD-20' (13017513745).jpg | Alan Wilson | CC BY-SA 2.0 | **the front nozzle's joint, exit and width**; the blow-in door cross-check; the anisotropy fit |
| `hover-nozzles-down.jpg` | United States Marine Corps AV-8B Harrier II hovering.jpg | D. Miller from IL. USA | CC BY 2.0 | **the undercarriage cross-check** — the two lowest points on the centreline, gear down |
| `three-quarter.jpg` | McDonnell Douglas AV-8B Harrier II (20050841606).jpg | wallycacsabre | CC BY 2.0 | structure only: a plan view as much as a side one |
| `deck.jpg` | AV-8B Harrier II-.jpg | — | Public domain | structure only: NOSE-ON, so it has no longitudinal scale at all |
| `nozzles-close.jpg` | Harrier vectoring nozzles.jpg | Mr.Z-man | CC BY-SA 3.0 | structure only: both nozzles, the front pair's rings and square exit, the rear pair's heat-staining and oblique cut |
| `ground-yuma-1.jpg` | MCAS Yuma Receives Harrier for Display (9109201).jpg | U.S. Marine Corps photo by Lance Cpl. Hannah Dodson | Public domain | structure only: the intake bell beside the front nozzle |
| `ground-yuma-2.jpg` | MCAS Yuma Receives Harrier for Display (9109202).jpg | U.S. Marine Corps photo by Lance Cpl. Hannah Dodson | Public domain | structure only |
| `ground-yuma-3.jpg` | MCAS Yuma Receives Harrier for Display (9109219).jpg | U.S. Marine Corps photo by Lance Cpl. Hannah Dodson | Public domain | structure only: **the fin root fairing**, which the model does not carry |
| `ground-celebration.jpg` | AV-8B Harrier II National Victory Celebration 2.jpg | SENIOR AIRMAN Jensen | Public domain | structure only |
| `ground-marina.jpg` | Marina Militare AV-8B Harrier II.jpg | Aldo Bidini | GFDL 1.2 | structure only, and an **AV-8B PLUS** — a nose 1.42 ft longer, so it may not be scaled against this model at all (§2) |

**The two that carry measurements are named as such and the other eight are not.** A wide-angle walk-round
with a person in shot settles what a thing looks like and can carry no scale; saying which is which in the
table is the point of the table.

---
## 6. MEASURED, off [SAC] page 2

`measure_sac.py` re-derives everything in this section **from the scan alone, reading nothing out of this file**, so the
two can disagree and one of them be wrong. Run it and read the residuals; every fit prints one.

**The scan is taken at its native resolution, not re-rendered.** The PDF's page 4 holds one embedded greyscale image at
**3510 × 2552**; rendering the page at 200 dpi gives 2340 × 1702 and throws away a third of the linear resolution that
is already there. Extracting the embedded image is lossless and free.

### The scale, and the trap on this sheet

**THE PRINTED `SCALE IN FEET` BAR IS UNUSABLE AND IS NOT USED.** Its five ticks give **15.20 px/ft** where four printed
dimensions across three views give **19.04 to 19.32** — the bar reads **20.8 per cent low**. It is not even internally
consistent: its four 5 ft gaps measure 73.9, 75.2, 77.8 and 77.1 px, a 2.3 per cent spread on sub-pixel centroids that
are individually good to about a tenth of a pixel.

This is worth stating loudly because **the bar is the one thing on the sheet that looks like a ruler.** Anything scaled
by it would have come out a fifth too small, uniformly, with nothing in the drawing to contradict it.

**The scale is set by the published 30.33 ft span and nothing else: 19.1889 px/ft. ONE PIXEL IS 15.9 mm**, so nothing
off this drawing is better than about 16 mm however carefully it is measured.

### The three views share one scale

| read from | px/ft |
|---|---|
| plan, the 30.33 ft span | 19.189 |
| plan, the 13.93 ft tailplane dimension | 19.042 |
| front, the 30.33 ft span | 19.321 |
| side, the 46.33 ft length dimension | 19.208 |

**Spread 1.45 per cent** about a mean of 19.190. One scale serves all three.

### The view is ISOTROPIC — the check that tests both axes

Scale-checking a drawing end to end says nothing about whether its two axes agree. The structural check is a printed
**AREA, ASPECT RATIO or M.A.C.**, because those combine both axes and no view's length goes into them. [SAC] prints all
three, plus the quarter-chord sweep. With the scale set from the **span alone**:

| | measured | printed | |
|---|---|---|---|
| Wing area | 225.86 sq ft | 230.0 | **−1.80 %** |
| Aspect ratio | 4.073 | 4.0 | **+1.82 %** |
| M.A.C. | 8.216 ft | 8.32 | **−1.26 %** |
| Sweep at 25 % chord | 31.10° | 30.62° | **+1.58 %** |

Area and aspect ratio are one fact, not two (AR = b²/S); the M.A.C. and the sweep are independent of them. All four
inside two per cent is the evidence that the drawing may be measured in both directions.

### The wing, MEASURED

Both edges tracked from the tip inboard over **every** station, with residuals:

| | |
|---|---|
| Leading edge | 132 stations, **rms 0.78 px (12.4 mm)**, sweep **36.50°** |
| Trailing edge | 114 stations, **rms 0.45 px (7.1 mm)**, sweep **10.95°** |
| Reference trapezoid, edges extended to the centreline | root **11.59 ft (3.533 m)**, tip **3.30 ft (1.007 m)**, taper **0.285** |

**THE TRAILING EDGE KINKS AT THE OUTRIGGER, and that was not arranged.** The TE runs unswept out to x = 1200 px and
sweeps back from x = 1225. The published outrigger station — half of the 17 ft tread, 8.5 ft out — lands at x = 1213.
So the kink in the drawn trailing edge and the outrigger's published position agree to about 3 px, **0.16 ft**, and
neither was used to find the other. It is also exactly what [SAC]'s prose says: the outriggers sit "between the flap and
aileron", which is where a flap ends and a trailing edge is free to change angle.

> **A residual caught a wrong answer that looked right.** The first run took the leading edge as the outermost ink at
> each station. The **pylons hang ahead of the leading edge in plan**, so it tracked pylons: the fit came back at
> **20.7 px rms (329 mm)** and gave an area 11.6 per cent high, an aspect ratio 10.4 per cent low, a M.A.C. 13.4 per
> cent high and a quarter-chord sweep 12 per cent high. Every one of those is a plausible number on its own, and four
> agreeing wrong figures look like a finding. Only the residual said otherwise. This is `modelling_here.md` section 3's
> cheapest rule, earning its place again.

### The parked stance, MEASURED — and the drawing disagrees with its own annotation

The scan is turned **+0.154°** (fitted down a panel rule that is vertical on the printed page, 2,000 rows, rms 0.495
px). The EA-6B's sheet from this same series was turned 0.26°; it is free to remove and every angle below has it taken
out.

The three tyres fitted as circles, with the **published sizes as an independent check — they did not set the scale**:

| tyre | radius | diameter measured | published | |
|---|---|---|---|---|
| nose (NLG) | 20.96 px | **26.21 in** | 26.0 | +0.8 % |
| main (MLG) | 21.15 px | **26.46 in** | 26.0 | +1.8 % |
| outrigger | 11.24 px | **14.05 in** | 13.5 | +4.1 % |

The outrigger is the worst because it is the smallest: at an 11 px radius the drawn outline's own ~1.3 px stroke is a
tenth of the radius. **Wheelbase 11.314 ft against the published 11.42, −0.93 %.** Four published figures that were not
used to set the scale, all returning within 2 per cent (the outrigger within 4) — that is what says the scale is sound.

**THE RAKE, three ways:**

| | |
|---|---|
| the drawn ground line, fitted over 445 px | **6.064°** (rms 0.277 px) |
| the two tyre centres' line | **5.953°** |
| **PRINTED on the sheet** | **6.5°** |

**The drawing and its own annotation disagree by about 8 per cent, and the model is built to the printed 6.5°.** The
geometry of this sheet is demonstrably less reliable than its figures — its scale bar is a fifth wrong — and 6.5 turns
up again in a *second document*: [NATOPS] p96 puts the fuselage about six and a half degrees nose-up at the hover stop.
One measurement off a photocopied scan does not overrule a figure that two documents print. The disagreement is
recorded rather than buried: 0.5° is about **12 cm of nose height** on a 14.1 m aeroplane, which is inside "good
enough, tune later" — but it is written down so the next reader can dispute it.

### Outstanding, named rather than invented

(Section 3: a stated gap with its remedy is a finding; a number in the same place is a liability.)

- **The four nozzles' stations.** Not in any table found. [SAC] page 2's front view draws the forward pair clearly as
  bulges either side of the lower fuselage, about **1.14 m out from the centreline**; the side view draws them but
  tangled with the wing root, the strake and gun pods and the gear, so the STATION is not yet taken. The engine's
  published 137.3 in (3.487 m) overall length is an independent ruler across all four. If that does not settle it they
  are an ESTIMATE and this file will say so.
- **Control surface travels for the ailerons and flaps** — [NATOPS] gives the stabilator and rudder only.

### The fuselage stations — taken, with what the extraction cannot do

`measure_stations.py` gives the side view's top and bottom outline and the plan view's half-width every 0.25 m from the
nose, **heights over the raked ground under each station**. It imports its scale from `measure_sac.py` rather than
keeping a copy.

**Two more published figures come back, neither of which set the scale:** the tallest drawn point **3.590 m** against
the published height of 3.551 (**+1.10 %**), and the widest half-width **4.622 m** against the 4.6225 semi-span
(**−0.00 %**). With the area, aspect ratio, M.A.C., quarter-chord sweep, three tyre diameters and the wheelbase, that
is **nine published figures the drawing returns within about two per cent on a scale set by the span alone.**

**A ROW REFUSES ITSELF RATHER THAN ANSWERING ABOUT THE WRONG OBJECT.** An aircraft in plan is symmetric, so a row
whose left and right extremes disagree is not measuring the aeroplane; 8 of 58 rows decline on that test and print a
dash. The two boxes on this page that sit inside the span and are not the aeroplane — the `SCALE IN FEET` bar and the
AIRFOIL DESIGNATION block — are masked by name as well, and both guards are needed:

- **Symmetry alone is not sufficient.** At row 1196 the scale bar lies to port and the airfoil text to starboard at
  nearly the same distance, so the row *looked* symmetric, reported a 4.686 m half-width at the nose, and was then
  taken as the plan's nose tip — putting every station 2.4 m out. Two independent errors can conspire to pass a
  symmetry check.
- **And a percentage tolerance alone is impossible to satisfy where the aeroplane is narrow.** At the nose the
  half-width is about six pixels and six per cent of that is a third of a pixel, so every nose row refused itself and
  the aeroplane came out 17 per cent short. The tolerance carries a 3 px floor. *A guard that cannot be satisfied is
  as useless as one that cannot fail.*

**Stated rather than chased:** the plan view's own nose-to-tail length reads **13.629 m against the side view's
published 14.122, −3.5 per cent.** The side view is the scale reference and its length is exact by construction, so
the plan's station index — and with it the `body_m` column — carries that 3.5 per cent. It is not enough to matter for
a fuselage section and it is written here rather than quietly scaled away.

**What it cannot do, said where somebody will look:** it extracts the drawn SILHOUETTE. Separating the fuselage proper
from the wing root, the gun and strake pods and the gear is a judgement made with [NATOPS] Figure 1-1's cutaway beside
the outline — a column of pixels does not know which part it belongs to. The F-35B's `SECTIONS` block carries the same
distinction by hand and says so.

> **Two datum errors that produced confident-looking nonsense**, both recorded in that script because both survived
> until a number exceeded what the aeroplane can be. Taking heights over ONE ground level rather than the raked ground
> under each station put the fin tip at 5.12 m against a published 3.551 — 14.1 m of nose-up rake is 1.61 m of error at
> the tail, and it looked like a badly drawn aeroplane rather than a badly chosen datum. And searching the plan view
> over the whole panel swept in the scale bar and the airfoil text block, returning half-widths of 5.8 m on a 4.62 m
> semi-span. **A search window is part of the measurement**: one that includes the wrong ink does not fail, it answers
> confidently about the wrong object.

---

## 7. The second pass at the fuselage — MEASURED off the FRONT view

The lane that built this aeroplane wrote, unprompted, that its fuselage "reads closer to an F-35 than to a Harrier:
too deep amidships and the rear fuselage does not taper enough", and that "the intakes do not read from the front".
Both were true. This section is what the re-measurement found and it does not replace section 6 — the top and bottom
outline taken there is sound, and eight of its stations agree with the drawing to a centimetre once
`station × tan(6.5°)` is added back to bring the raked-ground column into the level frame.

**What was wrong was not the outline but the RINGS.** `SECTIONS` carries four intermediate width/height pairs per
station, and every one of them had been judged — necessarily, because nothing on the sheet had been used that could
measure a cross-section. They put `chine_w` 0.3 to 0.5 m proud of its neighbours at every station, which is a chined
wedge, and made the body **1.44 m of half-width amidships**.

### [SAC] page 2's FRONT view — the instrument nobody had used

`measure_front.py`. The front view was used for one span cross-check and then dropped, yet it is the only view on the
sheet that shows a cross-section. It gives, MEASURED:

| | measured | against | |
|---|---|---|---|
| **Widest body half-width** | **1.231 m** | the model's 1.44 | the bells, not the fuselage |
| Front view's span | 9.308 m | published 9.245 | **+0.68 %**, and did not set the scale |
| Front view's outrigger tread | 5.242 m | published 5.182 | **+1.15 %**, off the 17.00 FT dimension's own extension lines |
| **Intake bell, JUDGED not fitted** | **1.222 m outer diameter**, centre 0.587 m outboard | — | **read off the front view; there is NO circle fit in `craft/harrier/` and the "2.56 px rms" this row used to quote belonged to nothing.** The figure is sound — it agrees with [WP]'s Pegasus to 0.2 per cent, and neither set the other — but its provenance was not. See the note at `propose_sections.py`'s intake print |

**The threshold sweep is flat.** The same measurement at every ink threshold from 60 to 225 returns 1.231 to 1.239 m.
The conclusion does not depend on where the line between ink and paper was drawn, and that is printed rather than
asserted.

**The wing and the pylons are excluded by CONTINUITY, not by a window.** A window cannot work here — the wing crosses
the body's own edge on its way outboard — so the body's outline is tracked upward from a row below the wing, taking
at each step the ink nearest a prediction from the last few accepted points. The track is **abandoned, loudly, at
y=1555** where the wing root merges with the body's edge. Port and starboard are tracked independently and a row is
refused unless they agree within 6 per cent or 3 px, whichever is larger; 65 of 65 shared rows passed.

### The bell's diameter and the engine's diameter, which were measured independently

**[WP]**'s Rolls-Royce Pegasus infobox: **"diameter = 48 in (1.219 m)"**. The bell fitted off the drawing is **1.222
m**. That is **0.2 per cent**, and neither figure went into the other — the bell came from a circle fit to a scan and
the engine from a table in a different document. A duct wrapping the fan face is the size of the fan, and the drawing
says so without being asked.

**The bell is built to the MEASURED 1.222 and never to the engine.** The Pegasus figure is used only as a one-sided
floor: two ducts feeding one fan of that diameter need an inner capture of at least 1.219/√2 = **0.862 m** each, and
the drawn throat is 0.94 m. *Nothing fitted to a bound the test then checks against* — this lane's rule, paid for
twice already.

### THE PLAN VIEW'S STATIONS ARE WRONG, AND SECTION 6 SAID SO WITHOUT ANYBODY ACTING ON IT

Section 6 records that the plan view's own length reads **13.629 m against 14.122, −3.5 per cent**, and judges it
"not enough to matter for a fuselage section". For a section's WIDTH that is right. **For a STATION it is not**, and
this pass walked straight into it: read off the plan, the intake bell began at station 2.00, and the first build put
the bells wrapped round the nose ahead of the windscreen.

Read off the SIDE view, whose scale is set by the printed 46.33 FT dimension's own extension lines, **the intake lip
is at station 3.30**. The side view wins. Worth recording honestly: the 1.30 m disagreement is **larger than the 0.49
m the length shortfall alone predicts**, so the plan's station index is not merely compressed — its origin is out as
well, and that is not fully explained here. Widths off the plan are unaffected, because a width is measured across
the axis that is in error rather than along it.

**No check caught this and none would have.** Every published figure still held, because not one of them is a
station. The picture caught it.

### What the second pass changed, and where each number came from

| | was | is | source |
|---|---|---|---|
| Widest body half-width | 1.44 | **1.216 drawn** | front view, 1.231 measured |
| Fuselage half-width at station 8.35 | 1.24 | **0.64** | plan view, both edges agreeing at 0.627 |
| Depth at station 9.75 | 1.92 | **1.400** | side view, 1.398 measured |
| Depth amidships (station 6.00) | 2.14 | **1.680** | interpolated between MEASURED 1.69 at 4.25 and 1.48 at 9.00 |
| Nose top, stations 0.75–2.25 | 0.14–0.20 m low | **on the drawn line** | side view |
| Windscreen base | 1.85 ESTIMATE | **1.20 MEASURED** | side view |
| Intake | box, stations 3.05–5.10 | **bell, 3.30–5.40** | side view for the station, front view for the circle |

**The ring is now an ellipse through its own top, bottom and widest point**, computed by `propose_sections.py`;
nothing in the five intermediate pairs is typed by hand.

### Still judged, and named so nobody mistakes it for a measurement

- **The fuselage's own width between stations 4.5 and 8.0.** The wing covers the fuselage side in plan and the front
  view is a projection that cannot say which station its widest point belongs to. Interpolated between measured ends.
- **The fuselage top from station 10.50 aft**, because the highest ink there is the FIN. Re-judged once, to a gentle
  rise to 3.34 (which is `FIN_ROOT_HIGH`, so the fin root sits on the spine); the previous 3.40→3.66 hump, paired
  with a belly raised to the drawn line, made station 12.00 deeper than station 10.50 and the tailcone visibly bulged.
- **The belly between stations 4.5 and 8.35**, because the lowest ink there is the GUN POD. *The first table followed
  that pod line*, which is how the body came to be 0.45 m too deep amidships and to swallow the parts hanging off it.
  A measurement of the wrong object, for the third time on this one sheet after the scale bar and the plan's stations.
