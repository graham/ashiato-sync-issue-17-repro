# Lockheed C-130H transport visual reference

Kind `transport` is the C-130H, added on 2026-09-19 (`lane/liners`) beside the AC-130U gunship. The user asked for the
real C-130 with "an 'armed version' and a non armed version (transport)". It is drawn by
`objects/vehicles/hercules_airframe.gd` with `armed` false: the same airframe as kind `gunship`, with a ramp to load by
and no guns, no gun ports and no sensor turret, in a lighter grey.

**Every measured figure, and the reasons for them, are in `cockpit/craft/gunship/sources.md`**: Lockheed Martin's General
Arrangement, its two scales, the J-30's plugs taken out to make the H, and the overlays at x1.000. Nothing is measured
twice.

## The simulation's shape

- The gunship's box, span and mass (`transport_shape` copies `gunship_shape`): 4.32 x 4.68 x 29.79 m, the 40.4 m span
  drawn only, 55 t. It flies on the gunship's handling (`default_handling`'s shared case).
- A crew of three: the pilot (left) and copilot on the flight deck, each `EYE_HEIGHT` under the drawn eyes (0.55 m either
  side, 3.40 m aft of the nose, 3.90 m up), and the loadmaster on the cargo floor (1.04 m up) forward of the ramp's hinge,
  facing aft down the hold.
- The bus: flaps, gear, trim, a display page, and the RAMP on the drop channel, as the V-22's is. No weapon, no master
  arm and no `gun_of`.

## Datum and axes

The gunship's: the origin at the centre of `HerculesAirframe.GEOMETRY`, forward `-Z`, up `+Y`, metres.
