# Looking for a CL-415 you can measure, and not finding one

**Conclusion first: Wikimedia Commons has no true broadside of a Canadair CL-415, so the water
bomber's fuselage sections have not been re-lofted and `craft/tanker/sources.md` still says they
are unmeasured.** This file is the search, the licences, and every rejection with its reason, so
that the next person spends their evening on something else — or, knowing exactly what is
missing, goes and gets it.

`measure_cl415.py` beside this file re-derives every number below from the images alone.

## What was searched

Six Commons full-text searches and five categories. `Category:Canadair CL-415` has **69 files**;
`Category:Bombardier 415`, `Category:De Havilland Canada DHC-515` and
`Category:Canadair CL-415 in flight` are all empty. **No line drawing, silhouette, SVG or
three-view of the type exists on Commons at all** — the drawing search returned nothing in any
format, which is the single most useful fact here.

**`Category:Canadair CL-215` (70 files) was deliberately excluded and is worth a warning.** It is
far richer in ramp-side photographs than the CL-415 category, and it is the wrong aeroplane:
**the CL-215, the CL-215T and the CL-415 are three different aircraft** — piston, turboprop
conversion, and the production turboprop development with powered controls and tailplane
finlets. Commons captions mix them freely. A first sweep of this pool came back mostly CL-215T
and would have been measured as a CL-415 by anyone not watching for it.

An earlier sweep also turned up eight files titled `Canadair CL-415 Kroatien 1..8`. They are one
photographer's holiday set of a single aircraft banking over a Croatian resort: eight
three-quarter belly shots of the same pass. **One set of eight is one candidate, not eight.**

## The screen, and why its own best answer is wrong

A CL-415 square from the side draws a silhouette 19.82 m long over 8.98 m tall: **2.21 wide for
1 tall**. Yaw it and that number rises, because the 28.6 m wing starts projecting into the
horizontal. So `measure_cl415.py` segments the airframe by paint colour and reports the
silhouette's aspect against 2.21.

**It works as a filter and it does not work as a detector, and the table below contains its own
counter-example.** `Manitoba Canadair CL-415.jpg` scores 0.97 — the best of the ten — and is a
**three-quarter view from the front**, with both wingtip floats and both propeller discs spread
right across the frame. It scores well because the wing projecting wide is traded off against a
low camera making the aeroplane tall. The aspect ratio cannot separate those two.

**A cheap screen that only rules things out is still worth writing** — it turned 69 files into
ten in a second, and looking at 69 photographs by eye produces an impression rather than a
record. But it cannot license the answer, and this file would be dishonest if it presented the
top row as the pick.

### And then the detector, which reverses the screen's ranking

`broadside.py` beside this file measures the angle off a **circle in the subject** — `lane/cooling`'s
free protractor. A circle seen at an angle is an ellipse whose minor over major is the cosine of
the angle off the circle's own axis, so it needs no published dimension, no camera data and no
scale. A main wheel's axis lies across the aeroplane, so square from the side it is a full circle.

Measured off the main wheel with `--box`, and both rejected on a number rather than an impression:

| photograph | aspect screen | **wheel says** | box (fractions of the image) |
|---|---|---|---|
| Manitoba Canadair CL-415 | 0.97 — ranked **first** | **38.2° off broadside** | `0.5539,0.6721,0.5864,0.7296` |
| Braunschweig … I-DPCD (DSC01377) | 1.12 — ranked fourth | **24.6° off broadside** | `0.5202,0.6870,0.5646,0.7687` |

**The detector ranks them the opposite way round from the screen, and the detector is right.**
The Braunschweig figure also agrees with an independent estimate made earlier from the separation
of its two propeller discs, "about twenty degrees" — two methods sharing no arithmetic, within five
degrees of each other.

**A CL-415 may be at most 2.0° off square** before its 28.6 m wing lies over its own hull by more
than the hull is wide (`square_enough(28.6, 19.8)`). Both photographs miss that by more than ten
times. So the finding stands, and it now stands on a measurement: **no photograph in the category
is a broadside, and the closest is twelve times too far off.**

## The candidates, with licences and reasons

`x2.21` is the silhouette aspect as a multiple of a true broadside's: 1.00 is necessary and,
as above, not sufficient.

| file | x2.21 | licence | author | verdict | why |
|---|---|---|---|---|---|
| [Manitoba Canadair CL-415](https://commons.wikimedia.org/wiki/File:Manitoba_Canadair_CL-415.jpg) | 0.97 | CC0 | — | **REJECTED** | three-quarter from the front; both floats and both propeller discs visible and widely separated. **The screen's own best score, and wrong.** |
| [Braunschweig … I-DPCD (DSC01377)](https://commons.wikimedia.org/wiki/File:Braunschweig_Airport_Vigili_del_Fuoco_Bombardier_Canadair_CL-415_I-DPCD_(DSC01377).jpg) | 1.12 | CC BY-SA 4.0 | Sebastian Thelen | **CLOSEST** | on a taxiway, unobstructed, whole aeroplane in frame — the nearest thing to a broadside in the category. Still yawed: the two propeller discs are plainly separated, which they cannot be square on. |
| [Braunschweig … I-DPCC (DSC00899)](https://commons.wikimedia.org/wiki/File:Braunschweig_Airport_Vigili_del_Fuoco_Bombardier_Canadair_CL-415_I-DPCC_(DSC00899).jpg) | 1.06 | CC BY-SA 4.0 | Sebastian Thelen | REJECTED | airborne, banked, seen from below and ahead; the whole underside is foreshortened. |
| [CL-415 at Boise, 2016-07-26](https://commons.wikimedia.org/wiki/File:Canadair_CL-415_water_bomber_fighting_a_fire_at_Boise,_on_2016-07-26_(42583503324).jpg) | 0.91 | Public domain | Forest Service, USDA | REJECTED | over a fire at distance, three-quarter, hazed by smoke. |
| [Two super Scooper filling on lake](https://commons.wikimedia.org/wiki/File:Two_super_Scooper_filling_on_lake_(53798751500).jpg) | 1.12 | Public domain | — | REJECTED | two aircraft at distance, neither filling enough frame, both three-quarter. |
| [Saludo, Gijón 2019](https://commons.wikimedia.org/wiki/File:Saludo._Canadair._Festival_A%C3%A9reo_Internacional_De_Gij%C3%B3n_2019._(48356673331).jpg) | 0.85 | CC BY 2.0 | — | REJECTED | airshow pass, banked away, tail-on quarter. |
| [Canadair CL-415 (32) septembre 2024 18](https://commons.wikimedia.org/wiki/File:Canadair_CL-415_(32)_septembre_2024_18.jpg) | 1.18 | CC BY-SA 4.0 | — | REJECTED | airborne three-quarter; the sea horizon crosses the hull. |
| [CL-415 at CFB Goose Bay](https://commons.wikimedia.org/wiki/File:CL-415_Water_Bomber_at_CFB_Goose_Bay.jpg) | 0.82 | CC BY 4.0 | — | REJECTED | three-quarter from the front, **and a maintenance stand and a tug stand in front of the hull and the starboard float** — the bases hidden, which is the fault `lane/cooling` rejected nine of its eleven towers for. |
| [Super Scooper filling on lake (53797387867)](https://commons.wikimedia.org/wiki/File:Super_Scooper_filling_on_lake_(53797387867).jpg) | 0.78 | Public domain | — | REJECTED | scooping; spray hides the whole hull bottom, which is the line a loft most needs. |
| [Super Scooper filling on lake (53798560128)](https://commons.wikimedia.org/wiki/File:Super_Scooper_filling_on_lake_(53798560128).jpg) | 2.87 | Public domain | — | REJECTED | long range; the aeroplane is 226 px tall in a silhouette that is mostly spray. |

**Nine of the ten fail for two reasons, and they are the same two `lane/cooling` found on its
towers: photographed at an angle, or the thing you need to measure is hidden.** For an aeroplane
those come out as *three-quarter* and *spray, stands and smoke over the hull line*.

## Why the closest candidate was still not used

`I-DPCD (DSC01377)` is a good photograph of a CL-415 and it is not a broadside. Measuring a loft
off it would need the yaw solved and the perspective divided out, and **the honest difficulty is
that the silhouette's own width is not the fuselage**: at roughly twenty degrees off, the 28.6 m
wing projects about 9.8 m across the view, comparable with the 19.8 m hull, so the outline that
looks like an aeroplane's side is a hull and a wing superimposed. Every station measured off it
would carry that error silently.

`modelling_here.md` asks for a stated scale and a caption that is a claim. **The claim available
from this photograph is "about twenty degrees off square, at unknown range", and a loft is not
worth building on it.** Leaving the by-eye sections in place and saying so in `sources.md` is
the smaller lie.

## What would finish the job

In order of how likely each is to be reachable:

1. **A stated-scale three-view.** De Havilland's DHC-515 spec sheet has one, and the file is
   linked from `craft/tanker/sources.md`; it was not fetched here because this lane's tool
   allowlist does not reach that domain and `curl` was used only against Commons. **Somebody
   with a browser can put a page image in the lane and this is a short job.**
2. **A true broadside photograph from anywhere licensed.** Airliners.net and Jetphotos have many,
   almost none reusable. The test is the propeller discs, not the aspect ratio.
3. **A measured drawing in a published reference.** Not in the repository.

The overall envelope does **not** need any of this: span, length, height and propeller diameter
are already De Havilland's published figures and `tests/aircraft_fidelity.gd` holds the drawn
model to the first three within two per cent. What is missing is only the shape of the hull
between them.
