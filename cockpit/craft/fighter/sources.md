# Fighter visual sources and boundary

This is an ORIGINAL procedural model of the two-seat F/A-18F Super Hornet, built in
`objects/vehicles/fighter_airframe.gd` from measured public references. No third-party mesh,
photograph, texture or protected squadron livery is incorporated: the references below were
studied and measured, and every vertex is this project's own geometry. Each figure in the
airframe names the reference it came from with the tag given here, or says ESTIMATE.

## References

- **[NAVY]** U.S. Navy, "F/A-18A-D Hornet and F/A-18E/F Super Hornet Strike Fighter" (fact file).
  <https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2383479/fa-18a-d-hornet-and-fa-18ef-super-hornet-strike-fighter/>
  Gives the envelope: 60.3 ft long, 44.9 ft span, 16 ft high, two crew for the F. **60.3 ft is
  18.38 m**; this file said 18.5 m until 2026-09-17, and the native hull keeps 18.5 m (0.65% over,
  inside the 2% contract). Cross-checked: flugzeuginfo.net 18.40 / 13.70 / 4.88 m; aerospaceweb.org
  18.31 / 13.62 / 4.82 m and a 500 sq ft (46.45 m²) wing.
- **[HARV]** NASA Armstrong Flight Research Center, F-18 High Alpha Research Vehicle three-view,
  public domain (created by NASA).
  <https://commons.wikimedia.org/wiki/File:F-18_HARV_3_view.gif>
  The LEGACY Hornet, measured on a grid at 0.0086 m/px (length 17.07 m over 1,984 px, half-span
  5.715 m over 664 px agree). Gives the wing's leading-edge sweep (25.6 degrees measured, 26.7
  published), root and tip chords (4.18 and 1.84 m), the fold line 4.0 m out, the LEX edge from the
  wing root 1.43 m out forward to the windscreen, the fins canted 18 to 19 degrees in the front view
  (20 published) with roots 2.0 m and tips 3.5 m apart, a 6.5 m stabilator span, a 3.05 m main-gear
  track, twin nose wheels and the hook's stowed line. Plan-form figures are scaled x1.118 for the
  Super Hornet's 25% larger wing.
- **[SHP]** Newresid, "F18Efamilyweb.jpg", an F/A-18E colour profile, CC BY-SA 3.0, **studied for
  proportion only**. <https://commons.wikimedia.org/wiki/File:F18Efamilyweb.jpg>
  Measured at 0.0151 m/px; its wheels come out at 0.77 and 0.57 m against the 30 in and 22 in
  tyres, which is the scale's check. Gives the side lines (nose tip 1.75 m up, belly 0.97 m, top
  2.82 m behind the canopy), the windscreen foot at 3.70 m and canopy end at 7.09 m aft of the nose,
  the canopy's top 3.38 m up, the nose gear 5.4 m and main gear 11.9 m aft, the intake lip near
  8.9 m and the fin's root leading edge at 12.9 m.
- **[F]** "Boeing FA-18F Super Hornet 1 (4821239705).jpg", a photograph of an F/A-18F side-on,
  CC BY 2.0, **studied only**. <https://commons.wikimedia.org/wiki/File:Boeing_FA-18F_Super_Hornet_1_(4821239705).jpg>
  Measured against its own canopy (so perspective cancels): the two crews' helmets are 0.32 of the
  canopy's length apart, 1.09 m; the pilot's eye about 3.05 m over the ground and the back seat's
  about 3.18 m, both +-0.15 m. These are the reference eyes the canopy is drawn round and the seats
  are to be moved onto.
- **[JB]** Joe Baugher, "Structure of F/A-18 Hornet".
  <https://www.joebaugher.com/navy_fighters/f18_2.html>
  The main undercarriage retracts aft and rotates 90 degrees to lie flat under the intake ducts;
  the twin-wheel nose gear retracts forward.
- **[WP]** Wikipedia, "Boeing F/A-18E/F Super Hornet".
  <https://en.wikipedia.org/wiki/Boeing_F/A-18E/F_Super_Hornet>
  The fuselage stretched 34 in (86 cm), the wing 25% larger, enlarged LEX, caret intakes in place
  of the legacy's oval ones, a dogtooth at the fold.
- Also studied, not measured into the model: U.S. Navy public-domain photographs of F/A-18Fs in
  arrested recoveries aboard USS Carl Vinson (141019-N-HD510-163, 141019-N-TR763-0702) for the hook
  and gear on deck.

## ESTIMATES

The fold's position on the Super Hornet (4.45 m out), the wing's anhedral (3 degrees) and
thickness, the stabilators' anhedral, the intake lip's rake, the hook's 2.1 m length and pivot,
the gear's leg geometry and door sizes, the pylon stations, the antennae and lights, the tactical
greys (FS 36320 and FS 36375 as sRGB approximations) are estimates and are marked so in the file.
How long the gear and hook take is not the airframe's: it draws an amount it is handed.

## Datum and boundary

- Craft model origin at the native hull's centre; `-Z` forward, `+Y` up, metres. Stations are
  metres aft of the nose tip, `z = s - 9.19`; heights are over the ground with the gear down,
  `y = h - 1.10`, the native hull's half-height, where a parked fighter's origin rests (1.0998 m,
  measured headless).
- Runtime source: `res://objects/vehicles/fighter_airframe.tscn`, through the package `visual`
  boundary intended for imported `.glb` scenes. It changes no native collision, flight, seat or
  network state; the gear and hook are drawn from the bus.
- Evidence: `tests/fighter.gd` (measured structure, gear, hook, lights, sockets, budget, package,
  a live-session gear command) and `tests/fighter_inspector_shot.gd --ortho` (views at 40 px/m for
  laying [HARV] over).
