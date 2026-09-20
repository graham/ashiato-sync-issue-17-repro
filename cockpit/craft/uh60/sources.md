# UH-60M-inspired craft source boundary

This craft is an original procedural model based on public dimensions and recognizable
configuration. It contains no copied mesh, texture, restricted station layout, or OEM art.

Primary dimensional source: U.S. Army, *FM 3-04 Army Aviation* (6 April 2020), figure and
table 5-2, UH-60L/M Blackhawk helicopter:
<https://rdl.train.army.mil/catalog-ws/view/100.ATSC/6896A0EF-5829-402C-A74D-4A2077812A09-1438345011901/fm3_04.pdf>

- UH-60M fuselage length: 41 ft 5 in (12.62 m)
- main rotor diameter: 53 ft 8 in (16.36 m)
- height at tail rotor: 16 ft 11 in (5.16 m)
- maximum gross weight: 22,000 lb (9,979 kg)
- cabin floor: 72 in by 151 in; cabin door: 68 in by 53.5 in
- published armament: two M240H 7.62 mm machine guns

Configuration cross-check: the U.S. Army describes the Black Hawk as its utility tactical
transport and the M model as a digital networked platform:
<https://www.army.mil/article/137588/uhhh_60_black_hawk_helicopter>

The four representative game stations follow the Army's public crew description: pilot,
copilot and two outward-facing crew-chief/gunner positions. The procedural exterior uses
the published twin-engine, four-blade main-rotor configuration and public silhouette cues.
Exact internal panels and systems are intentionally generic builder content.

## The drawn airframe, 2026-09-17

`Uh60Airframe` was rebuilt on `RotorcraftKit` by `lane/rotors`: a faceted twelve-sided fuselage
with a low nose and stepped windscreen, a thick swept tail pylon with the tail rotor canted
twenty degrees on its starboard side, a stabilator at its foot, engines with outboard-turned
exhausts, and the cabin doors run back open. Wikipedia's "Sikorsky UH-60 Black Hawk" infobox
gave the 3.35 m tail rotor and the 2.36 m fuselage width. The cabin is drawn 2.84 m across
and 1.78 m tall inside, larger than a Black Hawk's, so that both door gunners' stations,
which reach 1.35 m off the centreline at the floor, stand inside it. Fuselage length, rotor
diameter and height stay at FM 3-04's figures, and `tests/uh60.gd` measures each one from
the part it describes.
