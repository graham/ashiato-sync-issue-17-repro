# AH-64D Apache Longbow: sources

The runtime exterior is an original procedural model (`objects/vehicles/apache_airframe.gd`). It contains no downloaded
mesh, photograph, texture, trademark or livery. The references below were used for study and measurement only, and none
is incorporated into the game. The downloaded copies live in
`~/godotgames-drafts/2026-09-18/cockpit-apache/research/`.

## References and licences

| tag | what | where | licence |
|---|---|---|---|
| [ARMY] | "McDonnell Douglas AH-64 Apache 3-view line drawing.png", a US Army recognition three-view of an AH-64A, 574 x 385 px | https://commons.wikimedia.org/wiki/File:McDonnell_Douglas_AH-64_Apache_3-view_line_drawing.png | public domain (work of the US Army) |
| [W] | Wikipedia, "Boeing AH-64 Apache", Specifications (AH-64A/D), citing Jane's 2000-01 and 2010-11 and Bishop 2005 | https://en.wikipedia.org/wiki/Boeing_AH-64_Apache | text, figures quoted |
| [FAS] | FAS Military Analysis Network, "AH-64 Apache" | https://man.fas.org/dod-101/sys/ac/ah-64.htm | figures quoted |
| [F] | flugzeuginfo.net, "Hughes / McDonnell Douglas / Boeing AH-64 Apache" | https://www.flugzeuginfo.net/acdata_php/acdata_ah64_en.php | figures quoted |
| [TM] | TM 1-1520-238-10, Operator's Manual, AH-64A, section 4.8 "Area Weapon System 30mm, M-230E1" | https://apachehelicopter.tpub.com/TM-1-1520-238-10/css/TM-1-1520-238-10_271.htm | US Army manual, figures quoted |
| [P1] | "00-05159 AH-64D 1-2nd Avn; Camp Eagle, Wonju, South Korea US (3098520806).jpg", 3264 x 2448: a D with the Longbow radar, three-quarter from port | https://commons.wikimedia.org/wiki/File:00-05159_AH-64D_1-2nd_Avn;_Camp_Eagle,_Wonju,_South_Korea_US_(3098520806).jpg | CC BY 2.0 |
| [P2] | "301sq, 2007, AH-64D Apache, Apache, Q-05, Volkel - 1010274 (54041044937).jpg", 2560 x 1920: a Dutch D without the radar, three-quarter from port | https://commons.wikimedia.org/wiki/File:301sq,_2007,_AH-64D_Apache,_Apache,_Q-05,_Volkel_-_1010274_(54041044937).jpg | CC0 (the frame carries a photographer's credit; the Commons licence is CC0) |

**Commons has one Apache drawing.** About twelve API searches of Commons turned up nothing else: no three-view, no
schematic and no SVG. The category tree (`Category:AH-64 Apache`, `AH-64D Apache`, `AH-64E Apache Guardian`, 259 files) is
all photographs. [ARMY] is the same series as the Tomcat's small drawing.

## The variant

**An AH-64D Longbow.** The mast-mounted radar dome is what identifies it, and the D's Longbow Hellfire is fire-and-forget,
which is what a helmet lock wants. [ARMY] draws an A, which has no dome and no enlarged cheek bays; the dome's
proportions come from [P1].

## The scale, and what agrees with it

`craft/apache/measure_drawing.py` re-derives all of this from the PNG alone:

- **THE SCALE:** [ARMY]'s front view draws the main rotor edge-on, x 277 to 541, 265 px. Against [W]'s 14.63 m that is
  **0.05521 m a pixel**. A pixel is 5.5 cm, which is the resolution of every MEASURED figure below.
- The plan view's two blade diagonals read 269 px, +1.6 %. The plan is drawn at nearly the same scale.
- At the front view's scale, with nothing fitted to them:

| figure | measured | published | |
|---|---|---|---|
| length with rotors (side view) | 17.72 m | 17.73 m [W] [FAS] | -0.05 % |
| height over the tail rotor (front view) | 4.69 m | 4.64 m [FAS] (AH-64A) | +1.1 % |
| stub wing span (plan) | 5.08 m | 5.227 m [FAS] | -2.8 %: the drawn tips are rounded, so the model uses [FAS]'s |
| fuselage, TADS to the stabilator | 14.69 m | 15.06 m [W] "fuselage length" | **-2.5 %, unreconciled**; [W] gives no datum |

## Where the sources disagree

- **Height.** [FAS] gives 4.64 m for the A and 4.05 m for the D. [F] gives 4.20 m, and [W] gives 3.87 m. These are
  different datums (the rotor head, the tail rotor, the radar), and none of them is named. The model holds its tail rotor's
  top to 4.64 m, which is also what the front view measures.
- **Main rotor.** [F] gives 14.60 m against [W]'s 14.63 m. [W] is used.
- **Overall length.** [F] gives 17.30 m against [W] and [FAS]'s 17.73 m. The drawing measures 17.72 m.
- **Fuselage length:** see the table.

## ESTIMATES, and what they were reasoned from

- **The main blade's chord, 0.53 m (21 in).** This is the figure commonly quoted; it is not in any source above.
- **The Longbow dome is 1.10 m wide.** Its height (0.44 of its width) and its stem's length (0.42 of it) are MEASURED as
  ratios off [P1]. Nothing near the mast in [P1] is a known size, so the width itself is not measured.
- **The main gear track is 2.03 m.** In the front view, at 5.5 cm a pixel, the wheels are hidden behind the stores.
- **The pylons** are 1.25 m and 2.10 m out. The drawing's front view shows one store a side, at about 1.5 m.
- **The chin gun.** Its trunnion, 0.52 m up and 2.70 m aft of the TADS's front, and its muzzle, 1.44 m ahead of the
  trunnion, are MEASURED off the side view. Its limits are [TM]'s: "100 ... left or right of the helicopter centerline and
  up 11 to 60 down".
- **The crew's eyes** are placed under the drawn canopy (see the airframe's doc block).
- **The paint.**

## Deliberate deviations (the craft standard: look good, fly well, fit the crew)

- **The cockpit is 1.30 m across its panes, against [ARMY]'s 0.99 m (+31 %)**, because the user asked for room for the
  devices. It stays inside the drawn 1.93 m cheek bays, so the plan silhouette is unchanged.
- **The gunner's roof is 0.17 to 0.22 m higher than drawn, and his windscreen steeper.** This gives a 95th-percentile head
  its 0.25 m of room at an eye placed where he can see down past the nose.
- **The tailwheel is levelled.** [ARMY] hangs it 0.97 m above the main wheels' ground (y 286 against 303.5), which would
  park the helicopter 5.3 degrees nose-up. The simulation parks a craft on its box's floor, so the tail leg reaches the
  same ground. **What would settle it:** a true broadside photograph of a parked Apache, with both wheels' contact points
  and the boom's lower edge in frame.
- **The side view's tail is not used for heights.** Its tail rotor is drawn as a skewed X in perspective, and a
  2.79 m [F] rotor on the drawn hub would stand 5.6 m high. The tail rotor's hub is placed 1.395 m under the 4.64 m top,
  and the fin reaches 0.3 m over the hub.

## What stays authoritative whatever the model does

Once the Apache is a kind, the simulation's box, seats, gun table and pylons are the authority, and `tests/apache.gd`
holds the drawing to them. Until then the airframe's own box is the drawn body's (`ApacheAirframe.DEFAULT_HALF`).
