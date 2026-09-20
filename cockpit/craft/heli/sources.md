# Utility helicopter visual reference and migration boundary

The current `heli` package predates the reference-aircraft programme. Its small native
5.2 m fuselage, 12 m rotor, 900 kg mass, skids, and four stations describe a fictional
light utility helicopter. It must not be relabelled as a UH-60 while those incompatible
physics and dimensions remain saved under the stable `heli` kind.

The intended production successor is a distinct UH-60M-inspired craft. U.S. Army
[FM 3-04](https://rdl.train.army.mil/catalog-ws/view/100.ATSC/6896A0EF-5829-402C-A74D-4A2077812A09-1438345011901/fm3_04.pdf)
lists a 12.62 m fuselage, 16.36 m main rotor, 5.16 m height at the tail rotor, 9,979 kg
maximum gross weight, dual pilot seats, two M240H positions, and an 11-person troop
capacity. The distinct `uh60` package now supplies that craft kind and migration rather
than hiding it inside a visual-only swap.

The existing procedural exterior uses only original Godot primitives. Its datum is the
centre of its fictional fuselage envelope, forward is `-Z`, up is `+Y`, and one Godot
unit is one metre. Its main rotor, tail rotor, boom, skids, and outward-facing door-gunner
stations remain the stable compatibility contract; `craft/uh60/sources.md` records the
separate reference-scale successor.


## The drawn airframe, 2026-09-17

`LightHelicopterAirframe` (`objects/vehicles/light_helicopter_airframe.gd`) now draws this
craft in place of the collision box: a cabin shaped after the Bell UH-1 family, since a light
helicopter with two door gunners is a Huey to most people. Proportions only come from
Wikipedia's "Bell UH-1 Iroquois" infobox (14.6 m two-blade rotor, 2.6 m tail rotor, 12.8 m
fuselage). The numbers are the package's: the native 12 m rotor, and the four seat
poses the cabin is drawn round. The cabin is 2.44 m across, wider than the 1.9 m
collision box, so that the door gunners' stations stand inside it; collision is unchanged.

## The tail, measured, 2026-09-17

The tail boom, synchronised elevator, fin, tail rotor, tail skid and mast height are measured
off the public-domain **"Bell UH-1H Iroquois 3-view line drawing"** on Wikimedia Commons
(<https://commons.wikimedia.org/wiki/File:Bell_UH-1H_Iroquois_3-view_line_drawing.png>),
scaled by its own dimension lines: 41 ft 5 in fuselage over 1,268 px in the side view. The
lengths are mapped at this model's 0.884 scale. The heights are mapped through the cabin,
which was enlarged for VR players. Every figure is in `LightHelicopterAirframe._boom_and_tail`.
