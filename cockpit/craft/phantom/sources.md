# McDonnell Douglas F-4E Phantom II visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/phantom_airframe.gd`). It contains no downloaded mesh, photograph, texture,
trademark or livery.

## Which Phantom, and how it is known

**The F-4E, late production, slatted.** The user's request settled the mark: *"make sure it has a
forward facing gun as well (later models)"*. The internal M61A1 in an extended nose is the E onward;
the B, C, D and J had none and carried a pod when they needed one.

The rest of the variant is **not inferred from the drawing's date**. The F-4E's own flight manual
prints a MAIN DIFFERENCES TABLE with the C, D, E and G in columns, and it settles four things that
change the shape:

| | F-4C | F-4D | **F-4E** | F-4G |
|---|---|---|---|---|
| **Leading edge slats** | no | no | **YES** | yes |
| **Boundary layer control** | yes | yes | **NO** | no |
| **Hydraulic wing fold** | yes | yes | **NO** | no |
| **Internally mounted gun** | no | no | **YES** | no |
| Radar set | AN/APQ-100 | AN/APQ-109 | **AN/APQ-120** | AN/APQ-120 |
| Engines | J79-GE-15 | J79-GE-15 | **J79-GE-17** | J79-GE-17 |

Three consequences, each of which changed what was built:

- **Slats, not blown flaps.** The C and D blow their leading-edge flaps; the slatted E does not.
- **THE F-4E HAS NO WING FOLD.** The joint and its line exist and the panels fold by hand for
  storage, which is what the published folded span is for, but **there is no fold to animate and no
  cockpit control for one**. This lane was one step from building it as a step-2 moving part *and
  from using the folded span as a published cross-check nothing was fitted to* — a handsome piece of
  evidence for a mechanism the aeroplane does not have.
- **The AN/APQ-120 is the smaller solid-state set**, which is why the E's radome is slimmer as well
  as longer. The nose shape has a reason and a source rather than being styled.

## The references, and the licence line

None of these is incorporated into the game. All are held with a licence table in
`~/godotgames-drafts/2026-09-19/phantom/research/licences.md`.

- **[FM] the aeroplane's own flight manual** — *T.O. 1F-4E-1, Flight Manual, USAF Series F-4E
  Aircraft*, 1979, 482 pages, **public domain** (USAF technical order), a scan with no text layer.
  Section I DIMENSIONS, the MAIN DIFFERENCES TABLE on p. 8, and Figure FO-1 GENERAL ARRANGEMENT.
- **[TO] the general-arrangement three-view** —
  [`McDonnell Douglas F-4E Phantom II 3-view line drawing (manual).png`](https://commons.wikimedia.org/wiki/File:McDonnell_Douglas_F-4E_Phantom_II_3-view_line_drawing_(manual).png),
  2,078 × 2,488 px, **public domain**, from *Maintenance Instructions, Cross Servicing Guide for
  Phantom II Aircraft*, T.O. 1F-4C-2-1-1 Change 7, 1993, p. 1-16, via the National Museum of the
  USAF. **Eleven dimensions printed on it in metres.** This is what is measured.
- **[A] the cross-check** —
  [`McDonnell Douglas F-4E Phantom II 3-view line drawing.svg`](https://commons.wikimedia.org/wiki/File:McDonnell_Douglas_F-4E_Phantom_II_3-view_line_drawing.svg),
  the US Army air-defence recognition three-view, **public domain**, a vector file. For which way
  things go and nothing finer.
- **[PUB] the envelope** — Wikipedia's *McDonnell Douglas F-4 Phantom II*, § Specifications (F-4E),
  read 2026-09-19, citing Green 2001, NASA SP-468, Knaack and Lake 1992.

### [TO] AND [FM] ARE ONE AUTHORITY IN TWO UNITS

The drawing's printed metric figures are millimetre conversions of the manual's feet and inches:

| [FM], as printed | [TO], as printed |
|---|---|
| Span 38 ft 5 in = 11.709 m | 11.71 m |
| Span, wings folded 27 ft 7 in = 8.407 m | 8.41 m |
| Length 63 ft = 19.202 m | 19.2 m |
| Distance between main landing gear 17 ft 11 in = 5.461 m | 5.46 m |

**So they cannot cross-check each other, and this file does not use them as if they could.** Only a
printed figure agreeing with the INK is evidence. The one place they genuinely disagree is height:
[FM] says 16 ft 5 in (5.004 m) and [TO] prints **4.98 m**, which is 16 ft 4 in. One inch, two USAF
documents; the E-specific manual in original units is preferred and the drawing's figure is recorded.

## The envelope

Tags: **[FM]** the flight manual, **[TO]** printed on the drawing, **[M]** measured off [TO] by
`measure_manual.py`, **[PUB]** published, ESTIMATE where nothing gives it. The **fitted to?** column
is `lane/roadfleet`'s, and the discipline is entirely in the rows that say yes.

| Quantity | Figure | Tag | fitted to? | Note |
|---|---|---|---|---|
| Length | **19.202 m** | [FM] 63 ft | **yes** — it sets the plan view's scale | drawn 19.200 |
| Span | **11.709 m** | [FM] 38 ft 5 in | **yes** — it sets the across-axis scale | drawn 11.710 |
| **Height** | **5.004 m** | [FM] 16 ft 5 in | **YES, AND NOT CHECKED** | see below |
| Main gear track | **5.461 m** | [FM] 17 ft 11 in | no | drawn 5.46 |
| Wheelbase | **7.09 m** | [TO] | **no, and it sets the SIDE view's scale** | drawn 7.09 |
| Stabilator span | 5.0 m | [TO] | no | the plan's ink gives **4.97** |
| Wing area | **49.2 m²** | [PUB] | **no — a real check** | drawn **50.33** (+2.3 %) |
| **Quarter-chord sweep** | **45°** | [PUB] | **no — the best check here** | drawn **45.07** |
| Leading-edge sweep | **51.47°** | [M] | no | 0.51 px rms over 267 rows |
| Trailing-edge sweep | 13.57° | [M] | no | 0.63 px rms |
| Outer-panel dihedral | **12°** | [PUB] | no | drawn 11.99 |
| Tailplane anhedral | **23°** | [PUB] | no | drawn 23.00 |
| Dogtooth / fold station | **4.044 m out** | [M], plan view | no | the FRONT view's fold dashes give 4.059 |
| Nose gear axle | station **4.182 m** | [M] | no | from the printed wheelbase's own extension line |
| Main gear axle | station **11.272 m** | [M] | no | the same |
| Aerofoil | NACA 0006.4-64 root, 0003-64 tip | [PUB] | — | 6.4 % and 3.0 %; drawn thinner, and says so |
| Span, wings folded | 8.407 m | [FM] | **NOT USED** | see "outstanding" |

### THE PUBLISHED "45 DEGREE LEADING EDGE SWEEP" IS THE QUARTER CHORD

The Wikipedia article's body says the F-4 has *"a leading edge sweep of 45°"*. It does not. Tracking
both edges of the inboard panel by continuity from the tip, over the same 267 rows:

> leading edge **−51.469°** at 0.51 px rms; trailing edge **−13.572°** at 0.63 px rms.
>
> Three quarters of the first plus one quarter of the second — the quarter-chord line — is
> **45.062°**, against a published **45**.

**Six hundredths of a degree, and neither edge was fitted to anything.** Taking the sentence at face
value would have drawn a leading edge at 45 degrees: a wing visibly too straight, on an aeroplane
whose planform is one of the two or three things that make it recognisable at a distance — **and
every dimension check would have stayed green**, because length, span and area barely move. It is
`modelling_here.md`'s "correct a caption from the object" applied to a number instead of a
photograph, and `craft/phantom/mutants.py` keeps the wrong reading as a mutant.

### Why the height is fitted to, and therefore not checked

The sheet offers **three mutually inconsistent vertical scales** for its side view:

| from | px/m |
|---|---|
| the two printed heights' own arrows (3.33 and 3.28 m, agreeing to 0.16 %) | 98.67 |
| the drawn fin tip taken as the published 5.004 m | ~96 |
| the printed 3.33 m taken as the canopy top | ~92 |

They span four per cent and this lane could not reconcile them. **The scan also clips the fin tip**
— at the side view's own scale it stands about 8 px above the top edge, and the ink stops at y = 5 —
so the height is not measurable here at all. The side view is therefore taken as isotropic with its
own **100.42 px/m**, measured along the axis stations live on, and the fin tip alone is built to
[FM]'s 5.004 m. `tests/phantom.gd` does not check the height, because a bound you fitted to is not a
check: it would pass for ever while everything else was wrong.

### The sheet is stretched about one per cent ALONG the aeroplane

Four readings off the ink, and they sort themselves by axis:

| printed figure | view | px | px/m | axis |
|---|---|---|---|---|
| length 19.2 m | plan | 1,925 | **100.26** | along |
| length 19.2 m | side | 1,932 | **100.62** | along |
| span 11.71 m | plan | 1,164 | **99.40** | across |
| stabilator span 5.0 m | plan | 497 | **99.40** | across |

The two spanwise readings agree to the second decimal and the two lengthwise readings to 0.36 per
cent, while the groups sit **1.0 per cent apart**. Noise does not sort itself by axis. The
stabilator span is what proves it, because **nothing was scaled by it**. Checked end to end against
the length alone — which is how most drawings are checked — this sheet would have looked perfect.

**So sizes come from the published figures, and the drawing is asked only for proportions WITHIN
one axis**: a station at 100.4 px/m, a spanwise position at 99.40, and neither used to check the
other. The front view is 101.5 px/m, 1.4 per cent from the plan's, and is therefore asked **only
for angles and ratios**, which carry no scale at all — which is all the 12 and the 23 degrees need.

### The sheet is NOT turned, and that is a result

`modelling_here.md` says always check a scan for rotation; the EA-6B's was turned 0.26° and the
AV-8B's 0.154°. This one is not:

- **six long extension lines are dead straight within a single pixel column** over 250 to 380 rows,
  which bounds any page turn at **0.151°**;
- two long horizontal rules nevertheless slope by **−0.212°** and **−0.123°** at 0.26 px rms.

A real page turn tilts both axes consistently and by the same angle. These agree on neither sign nor
size, so what is present is **local warp in a photocopy**, and de-rotating would have *inserted* an
error rather than removed one. The consequence is an error bar, not a correction: a height read near
a ground line carries up to 5 px, **0.05 m**, of warp, and the side view's ground line is fitted per
column rather than taken as one row.

## Measured off [TO], by `measure_manual.py`

That script re-derives every [M] figure **from the drawing alone**, reads nothing out of this file or
out of the airframe, and prints every residual. Run it with the drawing beside it. Its own history is
worth keeping: it disagreed with the figures measured by hand twice, and both times the script was
wrong, for reasons that generalise —

- **masking the page's extension lines by a COLUMN WINDOW removes the feature the line points at.**
  The plan's nose extension line stands *on* the nose tip, five pixels short of the pitot; windowing
  it cost 43 px of aeroplane and read the length **2.2 per cent short**.
- **masking them by THINNESS eats the aeroplane's own long straight edges.** A stabilator leading
  edge is a two-pixel line running 300 px with blank page either side. That version deleted wing.

What works needs no masking and is object-derived: **the centreline is the row about which the
drawing best mirrors onto itself** (y = 1841.0 on a 36,895 px overlap), **a wingtip is a row that is
MIRRORED and a dimension line is not**, and the nose and tail are the outermost ink *on the axis* in
a group longer than the pen. The two wingtips then land 582.0 and 582.0 px off the axis.

### The dogtooth, and the one piece of evidence nothing here was fitted to

A single straight fit over all 447 tracked leading-edge rows gives 50.19° at **7.92 px rms**. A
two-segment fit, with the split **searched for rather than typed**, gives **0.99 px** — eightfold
better — and puts the break at **4.044 m out** with the two leading edges **316 mm apart** there.

And the **front view's** two dashed lines, the ones the 8.41 m folded span is printed between, stand
**4.059 m** out at that view's own scale.

> **4.044 m from a slope discontinuity in the plan; 4.059 m from a pair of dashed lines in the front
> view. 0.4 per cent apart, and neither was used to find the other.**

On a real F-4 the dogtooth *is* at the fold joint. That is `modelling_here.md`'s "two references
that never saw each other agreeing on a third quantity", and it is the strongest evidence on this
aeroplane. It also recovers something from the 8.41 m figure, which cannot itself be used.

## Datum and axes

Forward is `-Z`, up is `+Y`, one Godot unit is one metre. `PhantomAirframe` works in **stations**
(metres aft of the nose tip, which is the pitot's point) and **heights** (metres over the ground with
the gear down), as `SkyhawkAirframe` and `TomcatAirframe` do. The origin is the middle of the draft
simulation box, which rests on the ground.

**AND EVERY STATION IS ITS OWN MEASUREMENT.** `lane/harriershape` put an AV-8B's intakes round its
nose with every check green, because **not one published figure about an aeroplane is a station** —
lengths, spans, heights, tracks and angles all survive sliding a component anywhere along the body.
This sheet is a rare exception: the printed **7.09 m wheelbase is a station difference**, so its two
extension lines land on the two axles and it sets the side view's scale. The gear stations are
therefore measured; everything else along the body was read at that scale and the model says so.

## Still outstanding

- **`8.41 m, "width, wing folded"`, and what would settle it.** [FM] calls it a **span** with the
  wings folded — tip to tip across the folded aeroplane — so it is measured **over the folded
  panels**, which lean outboard, and it is **not** the fold hinge's spacing. The drawing's dashed
  lines stand 8.12 m apart, 3.6 per cent short of the figure printed between them, and that is not
  an error to split the difference on: it is a sign that two different places on the object are being
  named. **What would settle it:** a dimensioned drawing of the aeroplane with the panels folded, or
  a plan view with the fold hinge's station printed. Neither is on Commons.
- **The fuselage sections between stations 10.4 and 15.0.** The spine could not be separated from the
  wing in this scan and is **interpolated between the measured 2.73 at station 9.4 and the fin root**.
  It is the one judged stretch in the table and the model names it as judged rather than giving it a
  plausible number.
- **Four printed figures whose datum is now known but which are not all spent.** 3.33 and 3.28 m are
  the canopy and the fuselage top and are used. **3.45 and 1.83 m on the front view are not** — their
  extension lines are located in pixels, but which feature each is measured *to* is not settled, and
  `modelling_here.md` is explicit that a figure not yet used is a check not yet run.
- **Moments of inertia.** Nothing public was found for any F-4 mark. When there is a craft kind in
  step 2 they will be an ESTIMATE from component masses, and the model will say so in capitals, as
  the Hawkeye's do.
- **The intakes are crude.** They read as boxes standing off the skin with the gap open, which is
  what was asked for, but a Phantom's intakes are big and shapely and these are not yet.
