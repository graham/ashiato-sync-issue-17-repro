# Cessna 310R visual sources and boundary

This is an ORIGINAL procedural model of the Cessna 310R, built in `objects/vehicles/cessna310_airframe.gd` from measured
public references. No third-party mesh, photograph, texture, trademark or livery is incorporated: the references below
were studied and measured, nothing was copied or redistributed, and every vertex is this project's own geometry. Each
figure in the airframe names the reference it came from with the tag given here, or says ESTIMATE.

`craft/plane/measure_310l.py` re-derives every MEASURED figure below **from the drawing alone**, reading no number out of
this file. Run it in this folder with the drawing beside it. So this write-up and the script can disagree, and one of
them be wrong, which is the only way a research file audits itself.

## References

- **[L]** *Cessna Model 310L Owner's Manual* D436-13 (1967), the "PRINCIPAL DIMENSIONS" three-view, as restored on
  Wikimedia Commons: **public domain**, US defective copyright notice. 1,334 x 1,759 px, provided by the Vorbeck
  Research Library at Sporty's Academy.
  <https://commons.wikimedia.org/wiki/File:Cessna_310L_3-view_line_drawing.png>
  A factory sheet with eight printed dimensions on it: span 36 ft 11 in, length 29 ft 6 in (and a second 29 ft 3.25 in),
  height 9 ft 11.25 in, wheelbase 9 ft 6.75 in, track 12 ft 0 in, tailplane span 17 ft 0 in, propeller 6 ft 9 in, tip
  tank 10 ft 0 in, and a ground rake of 4 deg 30 min. It is **not committed to the repository**; download it beside the
  script.
- **[TCDS]** FAA Type Certificate Data Sheet **3A10 Rev 63**, US Government work, **public domain**.
  <https://twincessna.org/wp-content/uploads/attachments/3A10_Rev_63%20C-310.pdf>
  Section XXII is the Model 310R, approved 15 August 1974: two Continental **IO-520-M or IO-520-MB at 285 hp** and
  2,700 rpm; **two McCauley three-blade full-feathering propellers, not over 76.5 in and not under 74.5 in**
  (hubs 3AF32C87 with 82NC-5.5 blades, or 3AF32C504 with 82NEA-5.5); takeoff 5,500 lb, landing 5,400 lb, ramp 5,535 lb;
  **Vne 223 KIAS, Vno 181, Va 148**, flaps 15 deg 158 KIAS, flaps 35 deg 139, gear 138; wing flaps down 35 deg, ailerons
  20 up and 20 down, elevator 20 and 20, rudder 29.3 deg either way; datum at the **forward face of the fuselage
  bulkhead forward of the rudder pedals**; levelling on an external splice plate under the windows.
- **[AOPA]** AOPA's aircraft guide, Cessna 310R: 36 ft 9 in span, 32 ft 0 in long, 10 ft 7 in high, **179 sq ft** of
  wing, 4 ft cabin width, 3,358 lb empty, 5,500 lb gross, Vs0 72 KIAS, Vs1 79, climb 1,662 fpm, ceiling 19,750 ft.
  <https://www.aopa.org/go-fly/aircraft-and-ownership/aircraft-guide/aircraft/cessna-310r>
- **[RR]** RocketRoute's type page: 11.25 m (36 ft 11 in) span, 9.74 m (32 ft 0 in) long, 3.25 m (10 ft 8 in) high,
  16.6 m2 (179 sq ft), two 213 kW (285 hp) IO-520-MB. <https://www.rocketroute.com/aircraft/cessna-310r>
- **[OO-MSN]** Ad Meskens, "Antwerp Cessna 310R OO-MSN.jpg" on Commons, **CC BY-SA 3.0**, studied only. A near broadside
  of a parked 310R. <https://commons.wikimedia.org/wiki/File:Antwerp_Cessna_310R_OO-MSN.jpg>
- **[G-BODY]** Mark Harkin, "G-BODY Cessna 310R (13272134755).jpg" on Commons, **CC BY 2.0**, studied only. A 310R
  taxiing nearly head on, which is where the nose, the nacelles and the tip tanks read together.
- **[G-BGTT]** Aeroprints.com, "G-BGTT Cessna 310R (9143314862).jpg" on Commons, **CC BY-SA 3.0**, studied only. A
  broadside of a stored 310R fuselage: the cabin windows, the long nose and the deep aft window.

None of the photographs is incorporated in any form. They are kept with this licence table in
`~/godotgames-drafts/2026-09-19/cockpit-twin310/research/`.

## Why a 310L drawing is evidence for a 310R

The only factory three-view that can be read freely is the **L**'s, and the L is a 1967 aeroplane. It is legitimate
evidence for the R for one reason, and it is a published one: **[TCDS] lists the tip tanks as 51 US gal at arm +35 in on
every model from the 310J through the 310R** — eleven models, one tank, one station. The wing, the tanks, the fin and
the tailplane did not change. What the R added is

- a **lengthened baggage nose**. [TCDS]'s 310R section carries `350 lb nose (-31)` in its baggage table and **the 310Q's
  section has no nose entry at all**. That is the R's nose in a public-domain document rather than in a caption. The
  plug is the difference of the two published lengths, 9.74 - 8.992 = **0.748 m**, and it goes ahead of the firewall.
- **three-blade propellers** as standard, 76.5 in [TCDS], where the L's printed disc is a two-blade 6 ft 9 in.
- a deeper rear cabin window, drawn from [G-BGTT] and [OO-MSN] as an ESTIMATE.

So every station aft of the firewall is the L's plus 0.748 m, and the nose is drawn to the R's published length. This is
`lane/liners`' "a stretched variant's drawing can scale its parent" (`learnings/2026-09-19-liners.md`) run backwards, and
the residuals are printed rather than hidden.

## The scales, and what the page's own views disagree about

Each view is scaled by **one of its own printed dimensions** and every other printed dimension in that view is then a
check, with its residual:

| view | scale | set from | checks |
|---|---|---|---|
| front | **80.705 px/m** | printed 36 ft 11 in span | tank face to face +0.54%, main wheel centres +0.65%, propeller discs +1.35% and -1.06% |
| side | **81.802 px/m** | printed 29 ft 6 in length | rake 4.500 deg against a printed 4 deg 30 min (0.00%), fin top to ground +1.25%, wheelbase -1.18% |
| plan | **80.654 across, 81.743 fore and aft** | printed 17 ft 0 in tailplane; the aeroplane's own nose-to-fin extent | tank face to face -0.25%, tip tank length +0.74% |

**The page's two axes differ by about 1.35 per cent** and no view is better than about one per cent internally. So the
model takes **ratios** from the drawing and **absolute sizes** from the published 310R envelope. The two printed lengths
(29 ft 6 in and 29 ft 3.25 in) differ by 70 mm where one pixel is 12.2 mm: that pair cannot arbitrate anything and is
recorded only to say so.

**The propeller discs are the only true circles on the page**, and fitting both of their axes is the front view's
isotropy test: 160-odd arc points each at 0.31 px rms, diameters +1.35 and -1.06 per cent of the printed 6 ft 9 in. That
view is isotropic to about one per cent, which is what lets a height be read off it at all.

## How it stands, and why that is the number that mattered most

**[L] draws the aeroplane LEVEL and rakes the GROUND under it.** Its wing's lower line is horizontal to the pixel, and a
Hough sweep of the side view's dark ink finds one dominant family of long straight lines at **exactly -4.500 degrees** —
the printed 4 deg 30 min. So in the craft's own frame **the nose tyre hangs 0.228 m below the mains**, and on flat ground
a 310 stands 4.5 degrees nose-up.

Three readings agree and none of them saw the others:

| | measured |
|---|---|
| [L] side view, the two tyre bottoms against the fitted ground line | **0.228 m** |
| [L] front view, the nose wheel's ground pad against the mains' (19.5 px at 80.705 px/m) | **0.242 m** |
| [OO-MSN], a parked 310R's cheat line | falls aft |

`Cessna310Airframe.at()` is the only place that angle is applied, and `nose_drop()` is derived from the rake and the
wheelbase rather than typed beside them, so `tests/twin310.gd` can hold all three tyre bottoms to one plane and have
that be a real check. Reading the convention the other way round buries the nose wheel, which is what happened to the
P-38 and cost 0.264 m (`todo/warbirds--p38-lightning.md`).

**And which of the page's parallels is the ground has to be asked of the tyres.** There are fourteen lines in that family
and two of them lie below the aeroplane; taking "the lowest" read the height 8 per cent high with every other residual on
the page still healthy.

## The height

[AOPA] gives the 310R 10 ft 7 in and [RR] 10 ft 8 in. [L] prints **9 ft 11.25 in (3.029 m)** for the normal attitude and,
in a note on the same page, **10 ft 8.75 in (3.270 m) with the nose gear depressed**, adding 3 in for a rotating beacon.
The R's published height reproduces that depressed figure to within an inch, and the fin did not grow between the L and
the R. Measured off [L] the normal height is 3.067 m, +1.25 per cent on its own printed figure.

**The model stands 3.03 m to the fin cap and 3.14 m to the beacon**, and `tests/aircraft_fidelity.gd` and
`tests/twin310.gd` hold it to 3.105 — the printed height plus the printed 3 in. This is the same call
`craft/cessna/sources.md` makes about Textron's 2.72 m for the 172S, which is also labelled a maximum and which nothing
reproduces.

## The tip tanks, which are what a 310 is recognised by

| | measured off [L] | against |
|---|---|---|
| length | 3.071 m | printed 10 ft 0 in, +0.74% |
| width in plan, at its widest row | 0.533 m | — |
| depth end on | 0.46 m | — |
| centre off the axis | 5.345 m | its outer face carries the 11.25 m span |
| nose and tail | station 2.18 and 5.25 on the R | 0.97 m ahead of the wing's leading edge, 0.93 m behind its trailing edge |
| capacity | [TCDS] **51 US gal usable** at arm +35 in | the drawn body is 360 litres, of which 193 is fuel |

**THE TANK HAS NO FIN.** The brief that asked for this aeroplane said the tanks carry one aft. [L]'s plan and front views
draw none, and a native-resolution crop of [OO-MSN] shows the starboard tank ending in a bare cone with the nav light on
it. There is none in the model.

**AND THE CANT IS ABOUT A DEGREE AND A HALF, NOT THE PRONOUNCED ANGLE THE TYPE'S REPUTATION SUGGESTS.** The 310G
introduced "canted" tip tanks and everything written about the type says so, and the first draft of this model drooped
them six degrees on that basis. The front view refutes it: a tank drooped by an angle shows an end-on silhouette taller
than its own section by its length times the sine of that angle, and [L] draws the tank **0.570 m across by 0.520 m deep
against a section of 0.533 by 0.46**. So the droop cannot exceed `(0.520 - 0.46) / 3.071`, about **one degree**, and the
toe cannot exceed 0.7 — while a six-degree droop would have made that silhouette 0.78 m tall. The plan view measures the
toe directly at **1.13 degrees**, fitted over 67 rows at 3.1 px rms.

The model therefore draws **1.13 degrees of toe (MEASURED) and 1.5 degrees of droop (ESTIMATE, at the front view's
bound)**, and what makes the tanks read as a 310's is their size and place rather than an angle.
`tests/twin310.gd` asserts the toe, because that is the part a reference measured; asserting the droop would be
asserting an estimate.

**Outstanding:** a 310R sheet of its own, or a true plan or head-on photograph at a resolution where the tank's outline
is unambiguous, would settle the droop instead of bounding it.

## The wing's area, which is the strongest evidence on the page

`modelling_here.md` section 3 asks for a structural cross-check that combines a view's BOTH axes,
because scaling a drawing end to end says nothing about whether it is anisotropic. A printed AREA is
that check. The chord law is fitted ACROSS the plan view and integrated ALONG it, so the two axes go
in together and no view's length goes in at all:

| | |
|---|---|
| chord law, 108 stations at 78 mm rms | **1.990 - 0.1534 y** metres |
| tip chord at the tank's inner face, 5.079 m out | 1.210 m |
| mean aerodynamic chord | 1.632 m |
| **planform to the tank's inner face, both sides, carried through the fuselage** | **16.252 m2** |
| the early 310's published 175 sq ft | 16.258 m2 — **-0.04%** |

That agreement is the finding. A chord law measured across one axis and integrated along the other
landing within half a millimetre of a square metre on a published area says the plan view is
isotropic and the law is right, and neither could be known from the printed span alone.

**AND IT LEAVES THE 310R's PUBLISHED 179 sq ft UNEXPLAINED, which is worth saying rather than
smoothing over.** The wing did not change between the L and the R ([TCDS]: the tip tanks are 51 gal
at arm +35 in on both), so two published areas 2.3 per cent apart are two conventions, not two
wings. Carried out to the tanks' outer faces the same law gives 17.53 m2, five per cent ABOVE the R's
figure; solved for the station that does give it, 179 sq ft is the same law carried to **5.236 m
out** — 158 mm past where the structure ends and 109 mm short of the tank's centreline. That looks
like a wing area with part of the tank's own plan counted into it. It is a guess about a convention
and is marked as one; `measure_310l.py` prints the solved station so the guess can be argued with.

**What the model publishes, and what `lane/flightcore` should fly off.** `Cessna310Airframe.planform()`
gives **16.26 m2 to the tank's inner face** with a 10.16 m structural span, aspect ratio **6.34**, MAC
1.640 m and taper 0.575 — and `area_over_tanks` (17.49 m2, aspect 7.24) beside it. The wing's own
area is the right one for a lifting-surface integration; what a tip tank does to the effective aspect
ratio is an end-plate question, not a planform one, and saying which of the two a lift slope used is
the difference between an aeroplane that stalls where the book says and one that does not.
`tests/twin310.gd` measures **16.06 m2** off the drawn triangles themselves, -1.2 per cent of what
`planform()` publishes, so the aeroplane in the scene really does have that wing.

## A threshold sweep, so the next reader sees the test and not the claim

`lane/harrier` swept its own NAVAIR sheet from 60 to 210 after reading this lane's report and found
nothing moved — that drawing weights its outline like its dimension lines, so it has no threshold
that loses its subject. This one does, and `measure_310l.py` prints the sweep:

| threshold | stations | root chord | chord fall | rms | area m2 |
|---|---|---|---|---|---|
| 60 to 105 | — | — | — | — | **nothing measurable: the aeroplane is not there** |
| 120 | 28 | 3.414 | 0.6644 | 0.284 | 17.54 |
| 150 | 102 | 2.252 | 0.2377 | 0.123 | 16.75 |
| 180 | 107 | 2.038 | 0.1687 | 0.046 | 16.35 |
| 195 | 107 | 2.003 | 0.1569 | 0.077 | 16.30 |
| 225 | 106 | 1.996 | 0.1527 | 0.082 | 16.33 |

Below 120 there is no aeroplane; from 120 to 165 the fit is made through a partly-seen outline and
the root chord is out by up to 68 per cent; from 180 up it settles to 0.7 per cent on area.
**Every printed dimension on the page checks out to half a per cent at every one of those
thresholds.** That is the whole of the trap: the annotations never complain.

## The rest of the measurements

| | measured off [L] | note |
|---|---|---|
| wing chord, outboard of the nacelle | **2.033 - 0.1701 y** metres, fitted over 43 stations at 51 mm rms | never fitted through two ends |
| leading edge sweep | 2.25 deg aft | |
| trailing edge sweep | 7.45 deg forward | a 310's taper is mostly in its trailing edge |
| dihedral | **4.83 and 5.07 deg**, fitted over 131 and 136 stations at 3 mm rms | drawn at 5.0 |
| wing mid-chord height | 0.91 m at the root, 1.41 m at the tip | over the mains' contact plane |
| propeller centres | 3.726 m apart, 1.863 m either side | |
| thrust line | 1.214 m over the mains' contact plane | |
| nacelle | station 1.36 to 5.31 on the R, 0.85 m across by 0.90 m deep | |
| track | 3.682 m drawn | printed 12 ft 0 in, +0.65% |
| wheelbase | 2.880 m drawn | printed 9 ft 6.75 in, -1.18% |
| main tyre | 0.575 m across the strut fairing | |
| nose tyre | 0.465 m | |
| fuselage | 1.32 m wide by 1.49 m deep at the cabin | [AOPA]'s 4 ft cabin leaves a hand's width of skin |
| tailplane | 5.31 m drawn span, 0.92 m root chord, 0.49 m at the tip | printed 17 ft 0 in, +2.5% |

**The tailplane was read wrong first, and the way it was caught is worth copying.** A column scan of the plan view
returned a 1.9 m root chord, which over a 17 ft span is 8.8 m2 of horizontal tail — **half the wing's area**. What it had
swallowed was the 17 ft **dimension line**, drawn a centimetre above the stabiliser's own trailing edge, and the distance
from a dimension line to a leading edge looks exactly like a chord. Nothing in the drawing could have argued with it;
what did was arithmetic the drawing implies: a tail that size does not fly. **Ask a measurement for something it implies
— an area, a ratio, a loading — before believing it.**

## ESTIMATES

The fuselage's superellipse sections between the measured profile lines; the wing's section (a NACA 23012 to the two
terms a faceted model shows) and its incidence and washout; the tip tank's droop (bounded above by the front view) and
its ogive; the flap and aileron chords; the nacelle's section; the gear's retraction kinematics, which [TCDS] does not
publish; the cabin window stations, from [L]'s side view and the two photographs; the cabin floor and lining; the door
and the nose baggage door; the aerial, the pitot, the step and the lights; and the cheat line, which is the only livery
drawn.

## The look: faceted on purpose

"Let's keep a somewhat lower poly look to models, not too many very round edges, this will keep a better 'old school
feel' to things" (the user, 2026-09-17), with `objects/vehicles/hawkeye_airframe.gd` as the named reference. The counts
are the whole of it: **three points to a quarter of a fuselage section (a fourteen-sided ring) over twenty-five measured
rows, six cuts along a chord, eight sides to a tyre and a spinner, ten to a tip tank, twelve to a nacelle, four to a leg
or a rod, twenty to a propeller disc, and no smooth groups anywhere.** The whole aeroplane is **2,958 triangles** in 22
surfaces, against the Cessna 172S's 2,936 and the F/A-18F's 2,234; `tests/twin310.gd` holds it under 6,200 so nobody
subdivides it back.

## Datum and boundary

- **The model is authored LEVEL, as [L] draws it**: `s` metres aft of the nose tip, `h` metres over the plane the main
  tyres stand on, `x` metres to starboard. `Cessna310Airframe.at()` is the ONE place the 4.5 degrees of nose-up are
  applied, and it returns the craft's own frame: metres, `-Z` forward, `+Y` up, origin at the middle of the native hull,
  with the tyres on the ground the native hull rests on.
- Runtime source: `res://objects/vehicles/cessna310_airframe.tscn`, through the package `visual` boundary. **It changes
  no native collision, flight, seat or network state.**
- Moving parts: the flaps from the bus, the ailerons, elevators and rudder from the crew's linkage, the gear, and the
  propellers on the physics clock. Travels are [TCDS]'s; the gear's kinematics and the propellers' look are ESTIMATES.

## What stays authoritative, and where the simulation and this aeroplane part

The simulation gives the size and the model gives the shape (`modelling_here.md` section 1). On this kind they disagree,
and it is written down here rather than quietly drawn around:

- **`plane_shape()` in `cockpit_world.cpp` is not a 310R and never was any aeroplane.** Its hull is
  1.50 x 1.40 x **6.40 m** where a 310R is 9.74 m long; its `span` is 13.0 m where a 310R's is 11.25; its mass is
  **780 kg** where a 310R is 1,523 kg empty and 2,495 kg gross. The drawn aeroplane is true to the published figures and
  the invisible box is not. `Shape::span` is commented "drawn only" and the one gameplay reader found is
  `spray_yard.gd`'s wingtip spray, so nothing that flies reads either.
- **The four seat ANCHORS sit 0.48 m below this cabin's floor**, because an anchor is a play space's floor rather than a
  seat pan. What matters lands right: `CockpitStation.EYE_HEIGHT` puts a crew's **eyes 1.90 m over the ground**, which on
  this aeroplane is 0.87 m over the cabin floor and 0.25 m under its roof. The anchors are low and the eyes are right.

Both are native shape-table facts and a C++ turn of their own; `todo/twin310--the-310r-is-not-modelled-as-one.md` carries the
numbers.

- Evidence: `tests/twin310.gd` measures the envelope, the stance, the tip tanks, the gear's travel and the winding from
  the drawn triangles, and `craft/plane/measure_310l.py` re-derives every figure above from the drawing.
