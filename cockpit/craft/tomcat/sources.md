# Grumman F-14D Tomcat visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/tomcat_airframe.gd`). It contains no downloaded mesh, photograph, texture,
trademark or livery.

## Which Tomcat, and why

**The F-14D**, because the only drawing on Commons good enough to measure is of a D. The overall
dimensions below are the same for the F-14A, B and D; the D's recognition features are the twin
chin pod (IRST and TCS side by side) and no glove vanes. Nothing in the model is an A-only feature.

## The authority for the envelope, and the gap in it

**THERE IS NO GOVERNMENT THREE-VIEW OF THE F-14 ON COMMONS.** Every other aeroplane measured here
had one: the Prowler a NAVAIR Standard Aircraft Characteristics sheet, the Hornet NASA's HARV
three-view, the Cessna the FAA's data sheet. Searched on 2026-09-17: `Category:Grumman F-14 Tomcat
drawings`, `Category:Grumman F-14 Tomcat documents`, and about fifteen searches for three-view, SAC,
NATOPS, general arrangement and planform. Nothing printed. So this aeroplane stands on weaker
ground than the Prowler, and says so:

- **[D] the shape** (the same file the Wikipedia article uses as its F-14D schematic): [`F-14D.jpg`](https://commons.wikimedia.org/wiki/File:F-14D.jpg), a detailed
  F-14D schematic (front, rear, plan, underside and both sides) by the DeviantArt artist
  Niyansfarn, **CC BY 3.0**, 3028 x 4863 px. **It is a fan drawing, not an authority.** It prints no
  dimension. Every number taken from it is a ratio, and the published length gives the scale. It
  draws the wing only at full sweep and the gear up.
- **[A] the cross-check**: [`Grumman F-14 Tomcat.png`](https://commons.wikimedia.org/wiki/File:Grumman_F-14_Tomcat.png),
  a US Army air-defence recognition three-view, **public domain**, and only 574 x 385 px, which is
  about 0.08 m a pixel. It draws the spread wing solid and the swept wing dashed on one plan view,
  which makes it the only reference that shows both sweeps.
- **[PUB] the envelope**: Wikipedia's *Grumman F-14 Tomcat*, section "Specifications (F-14D)",
  read from the article's wikitext on 2026-09-17, infobox only. **Every figure is headed F-14D.**
  The infobox cites the US Navy's *F-14 Tomcat fighter fact file* (2003), NAVAIR's *Standard Aircraft
  Characteristics (SAC) F-14D* (July 1985, partially declassified), Spick 2000 p. 81, and *Flight
  International*, 30 March 1985. **The SAC is the primary source.** It is hosted on alternatewars.com,
  which this lane may not fetch; it is the drawing to ask for next. **The overswept 33 ft 3.5 in is
  NOT in the infobox.** It is the commonly quoted Grumman figure, and it stays unverified.
- **[NPS]** [*A wing rock model for the F-14A aircraft*](https://commons.wikimedia.org/wiki/File:A_wing_rock_model_for_the_F-14A_aircraft._(IA_awingrockmodelfo1094538532).pdf),
  a Naval Postgraduate School thesis, public domain. It has **no drawing**. It gives the F-14A
  data-base weight of 52,000 lb and inertias Ixx 51,509, Iyy 232,773 and Izz 275,627 slug ft2
  (69,800 / 315,600 / 373,700 kg m2). Those are for step 2, the flyable kind.

None of these is incorporated into the game. All are held with a licence table in
`~/godotgames-drafts/2026-09-17/cockpit-tomcat/research/`.

## The envelope

| | | | |
|---|---|---|---|
| Length | 62 ft 9 in | **19.13 m** | [PUB] F-14D. **The model is scaled by 62 ft 8 in (19.10 m), 3 cm short**, the figure used before the infobox was read. Left as is: 0.16% is invisible |
| Span, 20 degrees | 64 ft 1.5 in | **19.54 m** | [PUB] F-14D; solves the pivot's station |
| Span, 68 degrees | 38 ft 2.5 in | **11.65 m** | [PUB] F-14D; [D] draws 11.56 m, the model 11.55 (-0.9%), an independent check on the pivot |
| Span, 75 degrees overswept | 33 ft 3.5 in | **10.15 m** | NOT in the infobox, commonly quoted; **predicted 10.08 m (-0.7%), not fitted to** |
| Height | 16 ft 0 in | **4.88 m** | [PUB] F-14D; the ground is put 4.88 m under the fin tip |
| Wing area | 565 sq ft | 52.5 m2 | [PUB] F-14D, "wings only"; not asserted |
| Sweep range | 20 to 68 degrees, 75 on deck | | [PUB]; [D]'s wing LE measures **68.4 degrees** |

## Measured off [D], by `measure_drawing.py`

`measure_drawing.py`, beside this file, finds the five views by their ink and re-derives every figure
below from the drawing alone. It reads nothing from this write-up, so the two can disagree. Run it
with the drawing beside it: `python measure_drawing.py F-14D.jpg`.

- **The views agree on length**: plan 2,313 px, underside 2,303, the two sides 2,317 and 2,318. The
  scale is **121.1 px a metre, 8.26 mm a pixel**. That is fine enough for a canopy frame, and
  nothing here should be quoted closer than about 2 cm.
- **The drawing's wing is at 68 degrees**: its leading edge fits a line at 7 mm rms and a sweep of
  **68.4 degrees**.
- **At full sweep the glove and the wing are one leading edge**: the glove fits 68.7 degrees at
  18 mm rms, **0.3 degrees off the wing**. Fully swept, the Tomcat is one delta. That is the
  first thing to check in a picture of the model at 68 degrees.
- **The pivot**: 3.0 m out, **station 11.22**. The out is read at the glove's outer corner fairing,
  to perhaps 0.2 m. The station is the one that turns [D]'s drawn tip into the published spread
  span. **The overswept span is then a PREDICTION**: 10.08 m against the published 10.15. It is
  insensitive to the pivot's out, moving 10.06 to 10.11 over 2.8 to 3.2 m, so it checks the wing
  and the tip rather than pinning the pivot.
- **The panel, swung from 68 to 20 degrees about that pivot**: its exposed root runs **2.9
  degrees off the airflow**, so the root rib comes out nearly streamwise at the forward stop. That
  is what a swing-wing root rib is designed to do, and nothing was fitted to it. **Its leading edge
  lands 3.32 m out, where [A]'s public-domain drawing puts it.** [A] draws the 20-degree wing; [D]
  does not draw it at all. Tip chord 1.48 m; the spread tip trailing-edge corner lands at station
  14.44 and 9.77 out.
- **The root's leading-edge end is ON the fitted leading edge, at 3.5 m out.** The first pick sat in
  the rounded corner fairing, 0.3 m ahead of both fitted lines. It would have put a step in a
  leading edge that the drawing shows is straight, and it drew the 20-degree root at 3.23 m.

## The overlays: the drawn model laid over both references

`tests/tomcat_shot.gd` renders orthographic silhouettes at [D]'s own 121.1 px a metre. They lay
straight over the drawing at x1.000, pinned on the nose tip and nothing else:

- **Plan, 68 degrees, over [D]**: 2,311 x 1,397 px of model against 2,313 x 1,399 of drawing. The
  wing, glove, intakes, nacelles and tail sit on their drawn lines. Two things are left off: the
  glove corner's rounded fairing, and a few centimetres at the stabilator tips.
- **Side, over [D]**: the canopy, spine, fin and belly lie on the drawing. [D] draws the gear up
  and the model draws it down, so the wheels stand below the drawing, on purpose.
- **Rear, 68 degrees, over [D]**: pinned on a fin tip. The fins, their cant, the nozzle centres and
  the canopy agree.
- **Plan, 20 degrees, over [A]**, shrunk to [A]'s own 13.15 px a metre: **the spread wing lies on
  [A]'s spread wing**. Nothing at 20 degrees was taken from [A] except the 3.32 m root check, so this
  is the pivot and the panel predicting a drawing they never saw.

## Where the references disagree, said out loud

- **Height, lower half.** [D]'s side view and rear view agree on the fin, 2.35 and 2.38 m above
  its root. They disagree below the wing: nacelle bottom 1.65 m under the fin root in the side
  view, 1.40 m in the rear. The side view is used for every height, because it carries the scale;
  the rear view is used only for spanwise positions.
- **Span, [A] against [PUB].** [A]'s plan draws span/length = 1.00 against the published 1.023, at
  0.08 m a pixel. It is used for which way things go, never for a size.

## Datum and axes

Forward is `-Z`, up is `+Y`, and one Godot unit is one metre. `TomcatAirframe` works in **stations**
(metres aft of the nose tip) and **heights** (metres over the ground with the gear down), as
`SkyhawkAirframe` does. The ground is 4.88 m under the fin tip. The origin is the middle of the
draft simulation box, which rests on the ground.

## Still outstanding

- **A printed three-view.** NAVAIR's F-14 SAC and the NATOPS manual's general-arrangement figure
  both exist, and neither is on Commons.
- **The gear.** [D] draws it up and [A] does not draw it. Track, wheelbase and tyre sizes are
  ESTIMATES until a drawing with the gear down turns up.
