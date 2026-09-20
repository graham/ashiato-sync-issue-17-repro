# Lockheed Martin F-35B Lightning II visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/lightning_airframe.gd`). It contains no downloaded mesh, photograph, texture, trademark or livery.

**It is the F-35B, the short take-off and vertical landing variant**: the lift fan behind the cockpit under its big
rear-hinged door, the two auxiliary inlet doors on the spine, the louvre doors under the fan, a roll-post door under each
wing, and the swivelling nozzle. It is not an F-35A (no internal gun, no lift fan) or an F-35C (a larger folding wing).

## The authority for the shape

**[JSF]** The JSF Program Office's own orthographic renders of the F-35B, three separate views at 3000 x 2400 px each, on
Wikimedia Commons as [`F-35B_Top.jpg`](https://commons.wikimedia.org/wiki/File:F-35B_Top.jpg),
[`F-35B_Side.jpg`](https://commons.wikimedia.org/wiki/File:F-35B_Side.jpg) and
[`F-35B_Front.jpg`](https://commons.wikimedia.org/wiki/File:F-35B_Front.jpg), from `jsf.mil/downloads/mediakits/7763.zip`,
dated 2008-03-04. **PUBLIC DOMAIN** as "a work of a U.S. military or Department of Defense employee, taken or made as
part of that person's official duties". The 1115 x 786 composite
[`F-35B_three-view.PNG`](https://commons.wikimedia.org/wiki/File:F-35B_three-view.PNG) (public domain, "The High Fin Sperm
Whale", 2010) is the same three views, smaller; it is not used.

**The three views share ONE camera scale, and that was checked before anything was measured from them**: the plan span
reads 1,914 px and the front span 1,911 (0.16 per cent); the plan length 2,791 px and the side length 2,793 (0.07 per
cent); the side and front heights both 621 px. The scale is the published span over the plan's: **178.88 px a metre,
5.6 mm a pixel**. The length then comes out at **15.603 m against the published 15.6 (0.02 per cent)**, a figure the scale
was not set from, which is the check that the renders are isotropic.

**They draw the gear UP**, on a white ground, and no ground line. So the silhouette is taken by thresholding and a flood
fill from the border (the renders' pale highlights would otherwise open holes in it), and the ground is not in the drawing
at all -- see "The height" below.

`measure_views.py` re-derives every MEASURED figure in the airframe from the three images alone, reading nothing out of
this file. `overlay_views.py` lays `tests/lightning_shot.gd`'s orthographic silhouettes, rendered at the renders' own
178.88 px a metre, over them at x1.000 on a stated datum. `strip.py` lays the gear frames side by side. The renders and
the photographs are in `~/godotgames-drafts/2026-09-18/cockpit-lightning/research/`; none is incorporated into the game.

## The envelope, published

**[WP]** Wikipedia, "Lockheed Martin F-35 Lightning II", its "Differences among variants" table, for the F-35B: length
**51.2 ft (15.6 m)**, span **35 ft (10.7 m)**, height **14.3 ft (4.36 m)**, wing area 460 sq ft (42.7 m2), empty weight
32,472 lb (14,729 kg), internal fuel 13,500 lb (6,124 kg), max take-off "60,000 lb class", g limit **+7.0**. The engine,
F135: 28,000 lbf (125 kN) dry and 43,000 lbf (191 kN) with afterburner.

**[RR]** Wikipedia, "Rolls-Royce LiftSystem": the three-bearing swivel module "able to rotate through **95 degrees** in 2.5
seconds and vector 18,000 pounds-force (80 kN) dry thrust in lift mode"; the lift fan 20,000 lbf (89 kN), "of 50 inches
(1.3 m) diameter"; the roll posts 3,900 lbf (17 kN) combined; **41,900 lbf (186 kN) in all**.

## Measured off [JSF], at 178.88 px a metre

Stations are metres aft of the nose tip; heights are metres over the **belly datum**, the side view's lowest point (the
bay doors at station 9.0).

| | measured | model |
|---|---|---|
| Nose tip to the tailplanes' inner trailing corners | 15.603 m | 15.57 m drawn |
| Span, front view | 10.683 m | 10.66 m drawn |
| Wing leading edge | station 6.377 + 0.6745 x out, 130 rows, 4.3 mm rms (port 6.365 + 0.6743, 4.6 mm) | **34.0 degrees** |
| Wing trailing edge, outboard of the tailplane | 12.878 - 0.260 x out (port 12.858 - 0.253), 75 rows | 12.83 - 0.25 x out |
| Wing tip | 5.33 m out, 9.96 to 11.50 | the same |
| Tailplane leading edge | 12.82 at 2.0 m out to 14.05 at 3.6 | 37 degrees |
| Tailplane trailing edge | 15.33 at 2.0 m out to 14.94 at 3.6; the inner corner 15.57 at 1.0 m out | the same |
| Fin, side view (projected) | leading edge (12.05, 1.9) to (13.37, 3.4); trailing edge (14.03, 1.9) to (14.80, 3.4) | the same line |
| Fin, front view | 1.65 m out at 1.9 m up, 2.22 at 3.45: **canted 20.2 degrees** | 20.1 drawn |
| Fin root | the front view shows nothing between 0.92 and 1.46 m out at 1.6 m up: the fin reaches down to the boom at about 1.30 m | 1.43 m out, 1.30 up |
| Canopy, plan | glazing from 1.95 to 4.20, 0.60 m either side at its widest (3.8) | 2.25 m of glass |
| Canopy, side | glazing 1.47 to 2.20 m up; the top 2.22 at 3.5 | the same |
| Pilot's helmet, side | station 3.3, 1.75 m up | the eye |
| Intake mouth, front view | dark from 0.72 to 1.22 m out at 0.43 m up, 1.08 to 1.47 at 1.15 | the same four corners |
| Intake lip | plan: the outer lip leads, 4.22 at 1.47 m out, 4.45 at 1.08; side: the top leads, 4.22 at 1.15 m up | raked both ways |
| Nozzle, plan | serrated exit 13.4 to 13.85, 0.57 m either side | 0.45 radius at 13.85 |
| Fin tip over the belly datum | 3.466 m | 3.46 |

The overlays agree over **95.2 per cent** of the two silhouettes' union from the side, **96.9** in plan and **82.0** from
the front (`overlay_views.py`). The front's shortfall is the wing's root fillet and the lower body under the wing, which
the model's six facets a side draw more squarely than the render's blends; the plan and side are the views a reader
recognises the aeroplane by.

## The height

The published 4.36 m is to the fin tip WITH THE GEAR DOWN; the renders draw it up. So the ground is put 0.894 m under the
belly datum, which stands the fin tip at 4.36 m. **That makes the height a figure the model is built to, not one it can be
checked against**, and `tests/lightning.gd` says so beside its envelope check.

A photograph disagrees, and is recorded here rather than believed: the Cope North broadside
([`U S Marines load F-35B weaponry during Cope North 25 (8879641).jpg`](https://commons.wikimedia.org/wiki/File:U_S_Marines_load_F-35B_weaponry_during_Cope_North_25_(8879641).jpg),
US Marine Corps, public domain) read at face value puts the fin tip 4.68 m up, 7 per cent over. It is a rear-quarter view:
its two main tyres stand 280 px apart along the fuselage and its two fins 200, so depth is foreshortened and the nose is
further from the camera than the tail, and its canopy-to-fin ratio gives a nonsense 6.1 m height by the same method. A
photograph that fails its own cross-check cannot overrule a published figure. What would settle it: a true broadside of a
parked F-35B, or a published main-tyre size.

## The gear, ESTIMATE

Retraction geometry is not public. From the photographs (studied, not incorporated): the nose leg retracts forward into a
well under the nose, and the mains forward into wells outboard of the weapons bays, their big doors hanging from the
leg's outboard side. Tyres 0.64 m (mains) and 0.46 m (nose), from the Cope North broadside's main tyre at 0.71 of the
belly's height over the ground. The track, 3.2 m, is the fins' spread against the mains' in the same picture. The well
doors open, the legs travel and the doors shut again, and **each door stops short of where its leg leaves the belly**,
because a door that shuts after the gear is down cannot shut across the leg.

The cycle's shares -- doors over the first fifth, legs over the middle three, doors over the last -- are
`actuators_research.md` section 3.5's. How long the cycle takes is the user's to set: "the amount of time isn't
important right now, we just need to be able to adjust it" (2026-09-17, `actuators_research.md` 3.10).

## The rest, ESTIMATE

- **The lift fan's door** stands up 70 degrees, hinged at its aft edge; the **auxiliary inlet doors** open 50 degrees,
  hinged outboard; the **louvre doors** under the fan and the **roll-post doors** under the wings drop 80 and 60 degrees.
  All from photographs of hovering F-35Bs. They are open by a tenth of the nozzle's travel. The drawn fan is 0.86 m across
  rather than 1.3, because it lies over the skin inside the door's opening.
- **The weapons bays**: 6.50 to 10.60 (an AIM-120C is 3.66 m long), an inner door hinged at a keel strip 0.12 m out and an
  outer door hinged at 0.95 m out, meeting at 0.42, both opening 95 degrees.
- **The paint**: FS 36170 all over, the upper surfaces a shade darker so the chine reads in flat light.
- **Tessellation**: 12 facets a fuselage ring, 12 round the nozzle, 8 round a tyre and the fan; 1,548 triangles in all.

## Research files and licences

| file | source | licence | used for |
|---|---|---|---|
| F-35B_Top.jpg, _Side.jpg, _Front.jpg | JSF Program Office via Commons | public domain (US DoD) | every MEASURED figure |
| F-35B_three-view.PNG | Commons composite of the above | public domain | not used |
| U_S_Marines_load_F-35B_weaponry_during_Cope_North_25_(8879641).jpg | USMC via Commons | public domain | the gear's proportions, and the height it disagrees about |
| VMFA-214_loads_Australian_ordnance_on_to_USMC_F-35B_(8501795).jpg | USMC via Commons | public domain | studied; too close and wide-angle to measure |
| f35.wiki | Wikipedia's article text, fetched raw | CC BY-SA, quoted for figures only | [WP] |
