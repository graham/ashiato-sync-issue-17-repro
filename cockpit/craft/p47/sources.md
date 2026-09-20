# Republic P-47D-30 Thunderbolt visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/p47_airframe.gd`, on the shared kit `objects/vehicles/warbird_airframe.gd`). It contains no
downloaded mesh, photograph, texture, trademark or livery.

**It is the P-47D-30**, the bubble-top "Jug". The model shows what you notice first on the aircraft:
- the great round cowling of the R-2800 with the Curtiss paddle-bladed propeller;
- the deep, heavy fuselage, its belly carrying the turbocharger's ducting from the engine back to the turbo behind the
  cockpit, the intercooler's exits on its flanks, and the turbo's hood under the tail;
- the bubble canopy on a cut-down spine;
- the elliptical wing with its eight .50s;
- the elliptical tail with its dorsal fillet;
- the wide-tracked mains, which SHORTEN as they fold inward.

There is no P-47 kind yet (lane/warbirds step 2, 2026-09-19): the airframe is drawn, and dresses from its own draft box.

## The authorities for the shape

**[AN]** the USAAF's three-view from AN 01-65BC-2 p.3: "Republic P-47 Thunderbolt 3-view line drawing.png", Wikimedia
Commons (<https://commons.wikimedia.org/wiki/File:Republic_P-47_Thunderbolt_3-view_line_drawing.png>), 1724 x 2525 px,
**{{PD-USGov-Military}}**, with its printed dimensions.
- It draws the **razorback RP-47B**. Its notes give the P-47C-1-and-later fuselage: 8 in longer, 36 ft 1-3/16 in in all.
- It is the authority for what the D-30 shares with the B: the wing, the tail, the gear, the cowling, the fuselage below
  the canopy, and the envelope.

**[NACA]** NACA RM L8A06 (1948), Figure 1, "Three-view layout of the P-47D-30 airplane"
(<https://ntrs.nasa.gov/api/citations/20090022749/downloads/20090022749.pdf>, page 22), **public domain**. It is the
embedded 2552 x 2999 px 1-bit scan.
- It is the authority for what the D-30 changed: the bubble canopy, the cut-down spine behind it, the dorsal fillet and
  the 13 ft propeller.
- **It is a reduced sketch that disagrees with itself.** Its printed span is 40 ft 0-5/16 in, where every other source
  gives 40 ft 9-5/16. Its propeller is drawn about 6 per cent over its printed 13 ft. Its printed fin height over the
  thrust line is 7 ft 2-7/8 in, against [AN]'s 6 ft 10-1/32 for the same fin.
- So it gives SHAPES, registered on [AN]'s side view, and no scale of its own.

**[WP]** Wikipedia, "Republic P-47 Thunderbolt", its P-47D specifications:
- 36 ft 1-3/4 in (11.02 m) long, 40 ft 9-5/16 in (12.43 m) span, 14 ft 8 in (4.47 m) high;
- 300 sq ft (27.87 m2) of wing;
- the mains shortening about 9 in as they retract (citing Friedman, 1942).

Both drawings are study material, kept in `~/Desktop/godotgames-drafts/2026-09-19/cockpit-warbirds/research/` and not in
the repo.

## Reading two dimensioned scans

**Neither sheet has a dimension-free copy**, and [AN]'s dimension and extension lines closed the whole space between
its plan's wing and tail against the outline. [NACA]'s 1-bit scan also has gaps in its outlines.
- Each view is FENCED by a hull drawn by hand a few pixels outside the aeroplane (`tools/three_view.py`, `hull`). Ink
  outside it is taken out before the fill.
- The lines that still cross inside the fence are taken out between their ends. Each is found as a row whose ink runs
  more than half the view's width, and stopped 20 px short of the fuselage.
- The ink is grown 2 or 3 px before the fill and the silhouette shrunk back after, which closes the scan's gaps.
- The pen's stubs are opened off: shrunk 3 px and grown back.
- **Every fence, line and seed is in `measure_views.py`, so it can be re-read and disputed.** The fences took four
  rounds. The first cut the fuselage at the wing root and the nose, then both tailplane tips, then the tailplane's
  leading edge, and each leak showed in the gridded crop of the silhouette over the sheet.

## Each view has its own scale

**[AN]'s plan: three printed dimensions agree on one scale, 116.00 px a metre, to 0.05 per cent.** Those are the RP-47B's
length 35 ft 5-3/16 in (116.02), the tailplane's 16 ft 0-3/32 in (116.00) and the root chord's 9 ft 2 in (115.96).
- **The drawn SPAN is 0.95 per cent short of the printed 40 ft 9-5/16 in** on the same sheet: 12.311 m at the plan's
  scale. The front view draws it short too (114.33 px a metre at the printed span).
- The model is built to the printed span, its planform stretched spanwise by 12.429 / 12.311. `tests/p47.gd` holds
  the span to 0.3 per cent, since a wing built to the drawing would pass a 1 per cent check. Its mutant proves that.
- **The wing's drawn area**, the chord 0.75 m out (clear of the fuselage's 0.68) carried to the centreline, is 26.94 m2.
  At the printed span that is 27.20, against [WP]'s 27.87 (-2.4 per cent).

**[AN]'s side: 116.85 px a metre along it** by the B's length (+0.7 per cent on the plan's). Its heights come from its
two printed heights, the fin's top 13 ft 8-3/16 in over the level ground and 6 ft 10-1/32 in over the thrust line:
**119.65 px a metre up**, 2.4 per cent over its length. The P-51's sheet has the same fault the other way round.

**[AN]'s front:** its compass-drawn propeller disc is 3.677 m across at the plan's scale, against the printed 12 ft 2 in
(3.708, -0.9 per cent).

**[NACA]'s side**, registered: its nose and tail columns on the C-1's printed length (111.24 px a metre), and its fin's
top and its belly under the wing on [AN]'s heights (118.38 px a metre up).
- Its deck ahead of the windscreen then sits at 0.738 m against [AN]'s 0.811.
- The model lays [NACA]'s canopy and spine on [AN]'s deck, 0.08 m up, which is within a centimetre of the 0.07 printed.

**The published height is the third quantity.** Tail down with a blade vertical, the model stands **4.491 m** over the
three-point ground against [WP]'s 4.47 (+0.5 per cent). Level on its mains the fin stands 4.171, the printed 13 ft
8-3/16 in. [WP] gives no attitude; the model says which one it is.

`overlay_views.py` lays `tests/warbirds_shot.gd`'s silhouettes (116.00 px a metre, gear down, the propeller left out) over
[AN] at x1.000, on the spinner's tip from the side and above and on the propeller's axis from ahead. Two things are done
to the DRAWING first, and each filename says so:
- the C-1's 8 in are put in at station 1.80;
- each view is resampled by its own two scales.

**The plan agrees over 96.7 per cent. The side agrees over 89.8, or 92.3 outside the canopy and spine the B and the D-30
do not share. The front agrees over 70.0, or 66.9 outside the propeller's disc**; from ahead, [AN]'s tyres are dashed
outlines the fill cannot close.

## Datum and axes

- Stations are metres aft of the spinner's tip on the C-1 fuselage (the B's, plus 0.203 m at and aft of 1.80). The plug
  is put in behind the cowl flaps, an ESTIMATE, since the note says only "this dimension".
- Heights are metres over the thrust line; out is metres to starboard.
- [AN] draws the aeroplane level and rakes the ground at the printed 12 degrees. The model is built level on its mains,
  the box's floor the main tyres' bottom, 2.098 m under the thrust line ([AN]'s level ground line).
- The three-point ground through both tyres is raked **12.12 degrees** against the printed 12.

## What is measured, and against what

| | the model | against |
|---|---|---|
| length | 11.000 m | printed (C-1) 11.003, [WP] 11.02 |
| span | 12.428 m | printed 12.429, drawn 12.311 |
| height, level on the mains | 4.171 m | printed 13 ft 8-3/16 in |
| height tail down, a blade vertical | 4.491 m | [WP] 4.47 |
| track | 4.750 m | printed 15 ft 7 in |
| three-point rake | 12.12 deg | printed 12 |
| tailplane | 4.880 m | printed 4.879 |
| dihedral | 5.56 deg, front view's middles 2.5 to 5.5 m out, 4.9 mm rms | printed 6 |
| belly under the wing | 1.120 m under the thrust line, the fuselage 1.93 m deep | [AN] side |
| canopy top | 1.20 m over | [NACA], registered |
| propeller | 3.962 m | [NACA] printed 13 ft |
| eight .50s | 2.71, 2.87, 3.02, 3.23 m out | [AN] front's muzzles, at the printed span |

## The gear

- **The main tyres** are 0.864 m across and 0.229 wide: [NACA] prints "34 x 9 tire", and [AN]'s plan draws the stowed
  wheels as circles 0.853 m across. [AN]'s side view draws the tyre 0.965 m across; the printed tyre is built.
- **The legs** stand upright from ahead and raked forward from the side, pivoting in the wing at station 3.40, 0.26 m
  under the thrust line (ESTIMATE).
  - They fold inward to [AN]'s plan's wells (1.10 and 1.13 m out, station 3.57 on the C-1).
  - They **shorten 9 in on the way**: the lower half slides up the leg, 0.227 m measured against the published 0.229.
  - The wheel comes to lie within 0.1 m of flat inside the wing.
- **The inner doors** are hinged 0.62 m out, just inside the fuselage's side, and swing past upright to 105 degrees. At
  0.70 and 85 degrees, and at 0.66 and 100, the wheel passed through them at 28 and 32 per cent of the cycle, and
  `tests/p47.gd` found it.
- **The tail wheel** is 0.34 m across at station 9.04 ([AN]'s circle). It folds forward into the fuselage (ESTIMATE).

## What moves, and its travel

| surface | travel | source |
|---|---|---|
| ailerons | 15 deg each way | ESTIMATE; [NACA]'s graphs read about 12 |
| elevators | 30 up, 20 down | [NACA]'s graphs |
| rudder | 25 each way | ESTIMATE; [NACA]'s graphs read a little over 20 |
| flaps | 40 down | ESTIMATE |
| propeller | clockwise seen from the cockpit | 64 VAT rows, from the hub's distance |

The hinges come off [AN]'s plan's dashed lines and [NACA]'s printed spans.
- The flap runs from the fuselage's side to 11 ft 0 in out.
- The aileron runs 8 ft 4-15/32 in beyond that.
- The two hinge lines meet 0.15 m apart at the flap's end. Each bay of the wing is cut at the hinge of the surface
  behind it: a shared section left a white wedge ahead of the aileron's root in the first plan overlay.
- The flaps and ailerons are lofted through every row of the wing they span, so their trailing edges follow the ellipse.
  Two sections, one at each end, drew the aileron's trailing edge 0.6 m inside the curve.

## Outstanding, with what would settle it

- **Where the C-1's 8 in go.** The model puts them at station 1.80, behind the cowl flaps. A C-1-or-later three-view with
  printed stations would settle it.
- **The D-30's canopy.** It comes from a reduced sketch, registered and laid 0.08 m up. A dimensioned D-25-or-later drawing
  would replace it.
- **The pilot's eye, the seat and the cockpit's room** are step 5's.
