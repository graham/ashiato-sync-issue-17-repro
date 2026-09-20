# Cessna 172S Skyhawk visual sources and boundary

This is an ORIGINAL procedural model of the Cessna 172S Skyhawk, built in `objects/vehicles/skyhawk_airframe.gd` from
measured public references. No third-party mesh, photograph, texture, trademark or livery is incorporated: the references
below were studied and measured, the manuals were never copied or redistributed, and every vertex is this project's own
geometry. Each figure in the airframe names the reference it came from with the tag given here, or says ESTIMATE.

## References

- **[TEXTRON]** Textron Aviation, [Cessna Skyhawk specification](https://cessna.txtav.com/en/piston/cessna-skyhawk):
  8.3 m long, 11.0 m span, **2.72 m high**, four occupants, fixed tricycle gear, Lycoming IO-360-L2A, McCauley propeller.
  The height is quoted here and is NOT the contract; see "The height" below.
- **[IM]** Cessna 172S NAV III Information Manual 172SPHAUS-00, Section 1, figure 1-1 "Three View - Normal Ground
  Attitude" (© Textron Aviation; studied and measured only).
  <https://leaviation.com/wp-content/uploads/2021/04/C172SP_IM_2005_navIII.pdf>
  Rendered at 600 dpi and measured off its own dimension lines: the side view at 0.0026685 m/px (27 ft 2 in between the
  extension lines), the plan and front views at 0.003194 m/px (36 ft 1 in; 11 ft 4 in over the stabiliser comes out
  3.438 m, 0.5% short). The side view is to scale both ways: its propeller measures 1.905 m against 76 in. The FRONT
  VIEW's vertical is not (its fuselage is 1.11 m tall outside against a 1.22 m cabin inside), so it gives widths and
  angles only. Gives the side profile, the plan form of the wing and tail, the windows and doors, the strut, the fin and
  rudder lines, the dihedral (1.44 degrees over the wing, 1.92 under it), the track and the spats.
- **[NOTES]** the same manual's notes to figure 1-1: wheelbase 65 in (1.651 m), propeller ground clearance 11.25 in
  (0.286 m), wing area 174 sq ft, normal ground attitude with about 2 in of nose strut showing.
- **[MM]** Cessna Model 172R/172S Maintenance Manual 172RMM, chapter 6 (© Textron Aviation; studied only).
  <http://www.aeroelectric.com/Reference_Docs/Cessna/cessna-maintenance-manuals/Cessna_172R_1996on_MM_C172RMM.pdf>
  Length 27 ft 2 in, height (maximum) 8 ft 11 in, tail span 11 ft 4 in, track 8 ft 4.5 in (2.553 m), cabin 39.5 in wide
  (1.003 m) and 48 in floor to headliner; McCauley 1A170E/JHA7660 76 in; tyres 6.00x6 main and 5.00x5 nose; fuselage
  stations from the firewall (FS 0) and wing stations from the root (WS 23.62), the taper break (WS 100) and the tip
  (WS 208). Control surface travel: ailerons 20 up and 15 down, elevator 28 up and 23 down, rudder 17 degrees 44 minutes
  either way perpendicular to its hinge, trim tab 22 up and 19 down, flaps 0 to 30.
- **[TCDS]** FAA Type Certificate Data Sheet 3A12 (public domain).
  <http://www.aeroelectric.com/Reference_Docs/Cessna/cessna-misc/C172_FAA_typecert_3A12.pdf>
- **[EALT]** Huhu Uet, "Cessna 172 Skyhawk (D-EALT) 01.jpg", a 172S SP taxiing near broadside, CC BY 3.0, **studied
  only**. <https://commons.wikimedia.org/wiki/File:Cessna_172_Skyhawk_(D-EALT)_01.jpg>
  Scaled off its own gear: the near and far main tyres and the nose tyre put the camera 15.4 degrees off the beam at
  303 px/m, and the length that scale predicts, 2,419 px, measures 2,425. Gives the spinner 1.28 m over the ground, the
  beacon 2.34 m (corrected for the tail standing farther from the camera), the belly 0.44 m, the windows 1.17 to 1.52 m
  and the pilot's eye about 1.45 m up and 2.35 m aft of the spinner.
- Also looked at, not measured into the model: Werneuchen's public-domain "Cessna 172 Skyhawk line drawing.svg" on
  Commons, whose side view is drawn 5% longer than its plan view.

## The height

Textron's 2.72 m (8 ft 11 in) is labelled MAXIMUM, and no drawing or photograph reproduces it: [IM]'s own side view puts
the fin cap 2.30 m and the beacon 2.39 m over the ground, and [EALT] puts the beacon at 2.34 m. The model is built to the
measured **2.36 m** to the top of its beacon, and `tests/aircraft_fidelity.gd` and `tests/skyhawk.gd` hold it within 2%.

## ESTIMATES

The superellipse sections between the measured profile lines, the incidence (1.5 degrees at the root washing out to -1.5
at the tip), the flap and aileron chords, the Fowler flap's slide, the strut's section, the propeller blades' chord and
twist, the inlets' size, the exhaust, antennae, pitot and lights, the cabin floor, panel and bulkhead, and the cheat line.

## Where [IM] and the model part, and why

- [IM] draws the aeroplane about 1.5 degrees nose-up against [EALT] and the propeller clearance in [NOTES]: its spinner
  is 0.12 m higher than the clearance allows and its tailcone's belly 0.03 to 0.05 m lower. The model follows [NOTES] and
  [EALT] at the nose and [IM]'s shape everywhere else.
- [IM]'s side view draws the wing's root section only; the model's tips stand 0.14 m higher at 1.73 degrees of dihedral,
  so its side silhouette over the wing is higher than the drawing's.
- The windows' heads and sills (1.66 and 1.30 m) are between [IM]'s (1.70 and 1.32) and [EALT]'s (1.52 and 1.17).
- **How wide this fuselage is at each height, MEASURED off the drawn sections**, by scanning outward from the centreline
  until a ray leaves the skin, at the narrowest station between s 1.95 and s 3.01:

  | h | 0.56 | 0.62 | 0.70 | 0.90 | 1.30 | 1.60 | 1.75 | 1.80 | 1.86 |
  |---|---|---|---|---|---|---|---|---|---|
  | half-width | 0.35 | 0.42 | 0.48 | 0.52 | **0.54** | 0.53 | 0.52 | 0.51 | 0.38 |

  This is why `SkyhawkAirframe.cabin_room()` promises +/-0.46 from h 0.72 to 1.78 rather than the cabin's full width down
  to its floor: the box has to be true everywhere in it.

  **AND IT IS NOT EVIDENCE THAT THE BELLY IS WRONG**, though a first draft of this file said it was. [MM] gives "cabin
  39.5 in wide" and never says that width is AT THE FLOOR; it is a maximum, and the model reproduces it where a cabin is
  widest -- 0.55 half-width at h 1.30 to 1.66, a lining 1.04 to 1.06 m inside against 1.003 m published. A real 172's
  floor pan is narrower than its shoulder room. The lower superellipse's squareness of 4.0 remains an ESTIMATE that
  nothing here has measured, and turning one line of a manual into a defect report nearly had this aeroplane remodelled.
  **A published dimension has a datum, and "cabin width" is not "floor width".**
- **`CABIN_FLOOR` is 0.56 and is not derived from anything.** [MM]'s 48 in (1.219 m) floor to headliner, under the drawn
  1.875 m roof, gives 0.656 -- a tenth of a metre higher. The constant is tagged ESTIMATE and predates the arithmetic.
  Unresolved: it wants a measurement or a decision, not a quiet correction, because the seats, the panel and the
  declared floor all stand on it.

## The look: faceted on purpose

"Let's keep a somewhat lower poly look to models, not too many very round edges, this will keep a better 'old school feel'
to things" (the user, 2026-09-17), with `objects/vehicles/hawkeye_airframe.gd` as the named reference. The counts here are
three points to each quarter of a fuselage section (a fourteen-sided ring) over seventeen measured rows, six cuts along a
chord, eight sides to a tyre, a spat, a spinner and an inlet, six to a strut, four to a rod, twenty to the propeller's
disc, and NO smooth groups at all -- the reference airframe sets none either. Retessellating from the first version
(four points to a quarter, eleven chord cuts, sixteen-sided wheels, a forty-sided disc, smoothed skin) took it from 5,320
triangles to 2,936 and moved no measured figure: every geometry check passed unchanged, and the side profile sampled off
the overlay moved by at most 0.02 m. `tests/skyhawk.gd` holds it under 3,400 triangles so nobody subdivides it back.

## Datum and boundary

- Craft model origin at the native hull's centre; `-Z` forward, `+Y` up, metres. Stations are metres aft of the spinner
  tip, `z = s - 4.14`, so the drawn 8.28 m is centred on the 8.30 m hull; heights are over the ground, `y = h - 0.85`, the
  native hull's half-height, where a parked Cessna's origin rests (0.8499 m, measured headless on 2026-09-17).
- Runtime source: `res://objects/vehicles/skyhawk_airframe.tscn`, through the package `visual` boundary. It changes no
  native collision, flight, seat or network state.
- The seats do not yet sit in this cabin: the package's eyes are 1.90 m up and 3.24 m aft, 0.55 m either side, against
  [EALT]'s 1.45 m, 2.33 m and 0.27 m. Moving them is a native shape change and a package migration of its own.
- Moving parts: the flaps and trim tab from the bus, the ailerons, elevators and rudder from the crew's linkage, which only
  a machine aboard holds, and the propeller on the physics clock, still when parked. Travel is [MM]'s; the Fowler flap's
  0.18 m slide and the propeller's look are ESTIMATES.
- Evidence: `tests/skyhawk.gd` measures the structure and every travel from the drawn triangles and draws the surfaces
  from each machine's own bus over a loopback. Side, top and front renders at 100 px/m laid over [IM] on the spinner tip
  and the ground line are `screenshots/2026-09-17/cockpit-64` to `66`. Expected differences: the nose and windows sit
  0.10 to 0.15 m under [IM], the belly aft of the wing up to 0.05 m over it, the wingtips 0.14 m over [IM]'s root-only
  wing, and [IM]'s front view is not to vertical scale.
