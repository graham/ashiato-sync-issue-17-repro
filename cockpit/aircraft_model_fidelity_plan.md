# Aircraft model fidelity plan

Status: production baseline implemented on 2026-09-17; future source-asset/GLB passes use this contract.

This plan upgrades the aircraft from recognizable procedural previews to durable,
reference-based models while preserving the cockpit builder's saved station layouts.
The exterior mesh is presentation. Craft origin, physics, collision, devices and station
poses remain explicit game data and must not move just because an artist replaces a mesh.

## Progress through 2026-09-17

- The existing `gunship` procedural exterior now has an AC-130/C-130 silhouette: measured
  40.38 m span, tapered round fuselage, high tapered wing, four six-blade turboprops,
  Hercules tail, flight-deck glazing, sponsons, landing gear, EO/IR ball and port weapon
  apertures. Native extents, collision, physics, seats, gun origins and network state stayed
  unchanged, with assertions covering the model fittings and seat-anchor preservation.
- The current simulation still fits its legacy 25/40/105 battery. The model represents those
  three authoritative mounts; changing the native schema to the AC-130J's 30/105 fit is a
  separate gameplay migration and must not hide inside visual work.
- `CommandButton` and `GuardedToggleSwitch` are reusable builder parts for mission and safety
  panels. Both use the existing server-authoritative command route. The guard is local hand
  state; opening it sends no craft command.
- `tests/device_farm.tscn -- --devices=500` now constructs a configurable mix of real control
  models across station-sized packages. The 500-device run passed with five stations and a
  largest serialized station of 29,291 bytes against the 64 KiB transfer limit.
- The E-6B Mercury is now a distinct pilotable craft kind rather than an airliner skin. Its
  original procedural blockout follows NAVAIR's public 45.8 m length, 45.2 m span and 12.9 m
  height, with a 707-derived body, four under-wing turbofans, flight-deck glazing, public
  communications-fairing cues and original Navy-style markings. Pilot and copilot have dual
  controls; two explicitly generic operator stations establish the expandable mission cabin
  without claiming a real or restricted layout. `craft/mercury/sources.md` records the boundary.

- The optional visual-scene boundary is implemented in the immutable craft package. It
  validates metre units, axes, dimensions, transforms, sockets and actual mesh bounds,
  retaining the native procedural body whenever an asset is absent or refused. The builder
  inspector renders dimensions, origin axes, native collider, station eyes and sockets.
- `fighter` is now a distinct fully pilotable tandem-seat, F/A-18F-inspired carrier fighter.
  Its native model, two immutable stations, authoritative replicated controls, bounds,
  inspector, exterior and both initial seat views are covered by tests and dated evidence.
  Its current exterior measures 1,700 triangles, 19 draw surfaces and four materials.
- `cessna` is drawn as a measured Cessna 172S Skyhawk (`SkyhawkAirframe`, lane/skyhawk): 8.28 x 11.00 x 2.36 m, the
  height measured from the information manual's side view and a scaled photograph because Textron's 2.72 m maximum is
  reproduced by neither; 18 draws, 5,320 triangles, 3 materials. Its flaps, trim tab, ailerons, elevators, rudder and
  propeller are pure functions drawn from the bus and the crew's linkage; `tests/skyhawk.gd` measures structure and
  travel from the drawn triangles. The package's seats sit 1 m aft of and 0.45 m above the real front seats, and move
  in their own migration.
- `uh60` is now a distinct pilotable/networked utility helicopter at the Army's public
  UH-60M dimensions, with pilot, copilot and two outward-facing crew/gunner stations. Its
  semantic procedural airframe, immutable package, LOD budget and gallery/station evidence
  are checked independently; the small legacy `heli` remains unchanged for compatibility.

The reference-scale procedural fleet, performance budgets, visual-scene boundary and inspection
workflow are implemented. Future art work is an incremental source-asset/GLB replacement through
that boundary; the generic airliner and utility plane remain deliberately unnamed until their
gameplay roles choose compatible real references.

## Current gallery audit

**The table below is a roster and is going out of date faster than anybody re-reads it.** It
lists twelve kinds of the game's twenty-five and omits every ground vehicle, every ship, the pod,
the segway and the tower; its Priority column was assigned once and has not been re-derived
since, so `gunship` is priority 1 and finished while `heli` is priority 9 and is the simulation's
collision cuboid with a plank on top. **For which craft have actually been modelled, read
`craft_model_audit.md`**, whose two measured columns are computed by `tests/craft_model_audit` on
every run rather than typed here. This table stays only for the reference targets it names.

Run `craft_gallery.bat --finish=fine` from `cockpit/` to regenerate the evidence. The
final 2026-09-17 run pictured 24 craft and ended with `RESULT=PASS`; Segway is deliberately
skipped because it has no visible hull in that level -- and `craft_model_audit.md` records that
this makes it the one craft in the game nobody has ever looked at, measuring the highest HULL
reading of all twenty-five.

| Existing kind | Current reading | Reference target | Priority |
|---|---|---|---:|
| `gunship` | Tapered C-130 silhouette, four six-blade engines and asymmetric mission fittings | AC-130J Ghostrider | 1 |
| new `fighter` | Do not silently change the generic plane's physics or saved packages | F/A-18F Super Hornet, with tandem pilot/WSO stations | 2 |
| new `mercury` | A command aircraft deserves its own many-station craft | E-6B Mercury | 3 |
| `cessna` | `SkyhawkAirframe` measured against Cessna's 172S three-view: cabin, windows and doors, tapered braced wing, Fowler flaps and ailerons, swept fin, elevators and trim tab, rudder, two-blade propeller, spatted gear; its surfaces and propeller move; seats still to move into its cabin | Cessna 172S Skyhawk | 4 |
| `tanker` | Rounded amphibious body, high wing, twin engines and firefighting cues at reference scale | DHC-515 Firefighter | 5 |
| `hawkeye` | Reference envelope, rotodome, folding-wing and landing-gear cues | E-2D Advanced Hawkeye | 6 |
| `osprey` | Tapered body with the defining tilting nacelles, rotors, gear and twin tails | V-22 Osprey | 7 |
| `chinook` | Rounded cargo body, tandem rotors, ramp and landing gear | CH-47F Chinook | 8 |
| `heli` + new `uh60` | Legacy light helicopter preserved; distinct UH-60 baseline complete | UH-60M | 9 |
| `glider` | Slender tapered two-seat body, canopy and long reference-scale wing | DG-1001 Club two-seater | 10 |
| `airliner` | Recognizable four-engine jet, but generic and heavily faceted | retain as a generic transport until its gameplay role chooses a real type | 11 |
| `plane` | Reads as a generic light utility twin | retain as a compatibility craft; rename only through a package migration | 12 |

The F/A-18F and E-6B are additions, not visual swaps. Their scale, mass, flight model and
station count differ too much from existing craft for a mesh-only replacement to be
honest. The F/A-18F gives the builder a useful tandem-seat fast jet. The E-6B provides the
long-term stress case: flight deck plus many mission stations in a large cabin.

## The look: low poly, faceted, on purpose

**The user's direction, 2026-09-17:** *"let's keep a somewhat lower poly look to models, not too many very
round edges, this will keep a better 'old school feel' to things."* And, naming the reference: *"the current
'folding wing plane' has the right approach"* — that is the **E-2D Hawkeye**,
`cockpit/objects/vehicles/hawkeye_airframe.gd`. Read its tessellation before modelling anything new: its
rings, its `SIDES` constants (20 on a nacelle round, 32 only on the rotodome lens), its flat plating panels
and the note in `_rotodome_lens` that a turning dome "shows only in its facets".

**What this means, and what it does not.**
- **Faceted surfaces:** flat panels and hard creases in preference to smoothed curves; few segments on
  anything round (fuselage cross-sections, nozzles, wheels, funnels, pipes, arches); single-bevel chamfers
  rather than rounded corners; smoothing kept tight so an edge stays crisp.
- **It changes TESSELLATION, NOT SHAPE.** Every measured dimension, station, feature and clearance stays
  exactly as measured, and each model's geometry suite must pass unchanged across a retessellation.
- **Say it in the doc block.** A model's header states that the low-poly look is deliberate, with its segment
  counts, so nobody later "improves" it by subdividing.
- **Report the counts:** a model's report gives its triangles and draw calls beside the Hawkeye's for the
  same kind of part.

Applied on 2026-09-17 to the F/A-18F (`lane/hornet`, retessellated after its structure was measured), the
Cessna 172S (`lane/skyhawk`), the two merchant ships (`lane/fleet3`), the Skyfront hangar (`lane/hangar`),
the airbase's hangars and revetments (`lane/airbase`) and the EA-6B (`lane/prowler`).

## The model contract

Every reference aircraft gets a checked-in visual specification beside its craft package.
The minimum fields are:

```json
{
  "visual": {
    "scene": "res://assets/aircraft/ac_130j/ac_130j.glb",
    "units": "metres",
    "forward_axis": "-Z",
    "up_axis": "+Y",
    "dimensions_m": [39.7, 11.9, 29.3],
    "offset_m": [0.0, 0.0, 0.0],
    "rotation_deg": [0.0, 0.0, 0.0],
    "sockets": {
      "nose_gear": [0.0, -2.0, -8.0],
      "sensor": [-2.0, -1.0, -10.0]
    }
  }
}
```

This is the implemented revision-1 craft-package vocabulary. The ordered dimension triple
is span, height, length in metres. Stations remain the package's per-seat JSON documents;
sockets are stable craft-local names and coordinates inside the visual declaration.

`stations.json` owns seat and standing-station transforms relative to the craft origin.
`sockets.json` owns named hard points such as gear, control surfaces, propellers, rotors,
doors, sensors and weapons. Neither file may refer to Blender object indexes or generated
Godot child paths. A replacement model binds its named nodes to these stable sockets.

The model import layer must support a `PackedScene`/GLB visual per craft kind and retain
the current procedural builder as a fallback. Loading or failing to load the visual model
must not alter native physics, collision, authority or network state. The builder renders
the craft origin, axes, station ghosts and sockets independently of the model so bad scale
or alignment is immediately visible.

## Source asset layout

Use one directory per aircraft:

```text
art/aircraft/ac_130j/
  source.blend
  sources.md
  exports/ac_130j.glb
cockpit/assets/aircraft/ac_130j/
  ac_130j.glb
  materials/
cockpit/craft/ac_130j/
  visual.json
  stations.json
  sockets.json
```

`sources.md` records authoritative dimensions, the datum choice, image/blueprint sources,
the author and license of any incorporated asset, and the exact export settings. Reference
photographs may guide proportions; do not copy protected textures or redistribute a model
without an appropriate license. Keep editable sources separate from the runtime GLB.

Start each model at real metre scale and at the agreed craft datum. Apply transforms before
export. Use a small material set, named moving parts, clean normals and deliberate smoothing.
VR performance budgets are per aircraft: at most 100,000 visible triangles for the first
exterior LOD, 12 material slots, and 20 draw calls before instanced repeated parts. Those
are initial budgets to measure and revise, not excuses to lose a defining silhouette.

## Fidelity passes

Each aircraft moves through the same reviewable passes:

1. **Reference sheet:** three-view proportions, dimensions, origin, crew/stations and the
   features that make the type recognizable.
2. **Blockout:** correct length/span/height, wing planform, tail, nacelles, canopy/windows,
   gear stance and major openings. It must pass the craft gallery before detail work.
3. **Station fit:** place every seat and standing station inside the actual shell; run the
   all-stations forward-view gallery and fix occlusion, eye height and exits.
4. **Functional parts:** named control surfaces, gear, doors, rotors/propellers, sensors and
   weapons bind to stable sockets. Visual motion follows authoritative craft state.
5. **Surface pass:** limited PBR materials, glass, panel breaks, lights and markings that
   are original or properly licensed.
6. **Performance pass:** exterior and interior LODs, culled hidden cabin detail, instanced
   repeated objects and measured desktop/VR cost.

An aircraft is not complete because it looks good in Blender. It is complete when both
galleries, dimensions, stations, collisions and runtime budgets pass in Godot.

## Execution order

### 1. Put the asset boundary in the game — complete

Add optional visual-scene metadata to the versioned craft definition, validate metre scale
and axes, and load it through `VehicleCatalogue`/`VehicleView`. Preserve the procedural
fallback. Add tests that a visual replacement cannot modify native extents, physics ids,
station transforms or network serialization.

Add a model-inspection scene to the builder. It shows dimension lines, origin axes, collider
wireframes, station eye points and named sockets, and can toggle the exterior/interior shell.
This makes model iteration possible without repeatedly editing station JSON by hand.

### 2. AC-130J gunship vertical slice — complete

Build the short-body AC-130J silhouette at 29.3 m long, 39.7 m span and 11.9 m high. Include
the high wing, four six-blade turboprops, cargo ramp, flight deck windows, landing gear,
left-side 30 mm and 105 mm positions, EO/IR sensor and a simplified mission cabin. Fit the
two-pilot flight deck and gunner/mission stations from the builder, then prove every seat in
the station gallery. This is the highest-value replacement and exercises asymmetric devices,
many stations and a large walkable interior.

### 3. F/A-18F fighter vertical slice — pilotable baseline complete

Add a distinct craft kind based on the two-seat F/A-18F: 18.5 m long, 13.68 m span and
4.87 m high. Model the tandem canopy, twin tails, leading-edge extensions, rectangular
intakes, twin engines, folding wing boundary, arresting hook and carrier gear stance.
Create pilot and WSO stations. Use this aircraft to prove tight cockpit placement, shared
front/back devices and carrier-deck proportions. Keep F-16 as a later single-seat craft;
its bubble canopy, side-stick and reclined seat deserve a separate cockpit rather than a
reskinned two-seat package.

### 4. E-6B many-station demonstrator — pilotable baseline complete

The checked-in baseline adds the E-6B at 45.8 m long, 45.2 m span and 12.9 m high with four under-wing turbofans,
707-derived fuselage, flight deck, communications fairings and a simplified mission cabin.
The real aircraft's crew of 22 makes it the best production target for builder pagination,
station naming, access paths and many simultaneous device layouts. Start with a smaller
representative station set, then expand without changing existing station identifiers.

### 5. Upgrade the existing fleet — reference-scale baseline complete

Bring the Cessna 172S, DHC-515, E-2D, V-22, CH-47F, chosen utility helicopter and DG-1001
through the same passes. Favor the craft whose existing station gallery exposes the worst
shell or visibility errors. Defer cosmetic refinement of the generic airliner and utility
plane until their gameplay roles select a real reference and compatible flight model.

## Required evidence for every aircraft

- authoritative length/span/height assertions and model bounds within 2 percent
- craft-gallery exterior screenshot from the standard camera
- all-stations gallery with the small reference level visible from every initial eye pose
- side, front and top model-inspector captures with axes, seats and colliders enabled
- no station identifier or transform drift without an explicit package migration
- no physics/collision change hidden inside a visual-only commit
- desktop frame/draw-call/triangle measurement, followed by the VR path before release
- a saved cockpit package loaded again after the model is replaced

The craft and station galleries are review artifacts and regression evidence. Keep the
latest accepted images in the normal dated screenshot directory; do not use screenshots as
the source of truth for geometry.

## Authoritative starting references

- F/A-18E/F dimensions, crew and configuration: U.S. Navy fact file,
  <https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2383479/fa-18a-d-hornet-and-fa-18ef-super-hornet-strike-fighter/>
- F-16 dimensions and cockpit features: U.S. Air Force fact sheet,
  <https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104505/f-16-fighting-falcon/>
- AC-130J dimensions, crew and weapon fit: U.S. Air Force fact sheet,
  <https://www.af.mil/About-Us/Fact-Sheets/Display/Article/467756/ac-130j-ghostrider/>
- E-6B dimensions, crew and role: NAVAIR,
  <https://www.navair.navy.mil/product/E-6B-Mercury>
- Cessna 172S dimensions and occupancy: Textron Aviation,
  <https://cessna.txtav.com/en/piston/cessna-skyhawk>
- DHC-515 dimensions and firefighting configuration: De Havilland Canada specification,
  <https://dehavilland.com/wp-content/uploads/2025/01/DHC-515_Spec_Sheet_v14_DIGITAL.pdf>
- DG-1001 dimensions and two-seat configuration: DG Aviation,
  <https://www.dg-aviation.de/en/dg1001club_en-2/>
- C-130J family proportions and propeller configuration: Lockheed Martin brochure,
  <https://www.lockheedmartin.com/content/dam/lockheed-martin/aero/documents/C-130J/C-130Brochure_NewPurchase_May2020_Web.pdf>

These sources establish dimensions and configuration. A modeler still needs licensed
three-view material and close-up references for shapes not defined by a fact sheet.
