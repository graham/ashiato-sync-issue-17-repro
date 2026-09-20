# Pouring many parts into one mesh, with the moving parts still moving

**The user asked** (2026-09-17): *"Would it be possible to build a function that turns a bunch of
objects into a single static one? ... I'd want to do this for planes as well, where they would have
surfaces that can move, like ailerons, flaps, gear, etc."*

## The answer, first

1. **It works.** One mesh with a bone per part, the control surfaces included. On the Cessna, draws go
   18 → 5, pixel-identical parked and flown through a real server and client, and every flap, aileron,
   elevator and rudder is 0.0000 m from where its part puts it. It is still identical 100 km out on
   the double build. Across the fleet, 508 surfaces become 117. **Nothing declares which parts move,
   and that is why no flag, group or name convention was needed:** every part gets a bone, a part that
   never moves keeps a constant pose, and the only authority for what moves is the pattern node the
   airframe's own `set_flaps` already turns. There is no second roster of movers.
2. **As built, it is slower on this PC. The cost is the posing, not the rendering.** 100 Cessnas, vsync
   off, six pairs with the order alternated, on a quiet machine, every pair agreeing on the sign:
   - Mobile with shadows: cast **+2.55 ms a frame** (pairs +2.48 to +2.90);
   - Forward+ with shadows: **+3.07 ms** (+2.92 to +3.40).

   Merging saves about **3 µs a Cessna** on an RTX 5080 under D3D12, where 1,800 instances cost half
   a millisecond to submit (about 0.3 µs each). Posing 17 bones from GDScript every frame costs about
   **25 µs**. These are the viewport's measured milliseconds, not the renderer's draw counter, which on
   Mobile counts objects (section 2).
3. **Where it wins today: a static weld of things that never move.** The same castings, never posed,
   are **−0.31 ms** (−0.42 to −0.19) per 100 craft. That suits a building authored as nodes, but the
   buildings here are already one mesh or one MultiMesh (section 1). Their remaining cost is copies,
   such as twenty cooling towers, and a copy wants a MultiMesh, not a bake.
4. **Two ways moving craft could pay: get posing under about 3 µs a craft.**
   - **Try first: pose only on a change the airframe announces.** A parked or cruising craft moves
     nothing most frames, so most frames would cost nothing. It is GDScript only, and it is a small
     change: `draw_the_skyhawk_from` already knows when the bus or the linkage changed.
   - **Try second: pose in C++.** It is the robust fix for craft whose surfaces move every frame, but it
     needs the C++ slot, and a C++ change is always the dearer one here.

   Either way, the never-posed −0.31 ms per 100 craft is the most it can win on this machine.
5. **The unmeasured case that may reverse all of this: a Quest-class GPU, where a draw costs more.
   This game targets a headset. "It loses" is a measurement on an RTX 5080, not the final word.**

**And the cheaper win on a craft today is shadows.** A Cessna with its cabin fitted is 220 draws on
Forward+ with shadows, 142 of them shadow draws. Switching shadow casting off on its 67 cabin meshes
takes it to **106**. Pouring the airframe alone takes it to 182; both, to 68. From outside the switch
changes 0.9 to 1.2 per cent of the craft's pixels. **Nobody has looked from the seat.**

**A hard precondition on any casting shipping:** `DrawnParts.adrift`, `DrawnParts.count` and
`named_parts` must skip `Casting.CAST_FROM` in the same commit (section 5). A part built adrift and
then poured is otherwise hidden from the fleet join check: 0 found with the casting walked, 1 without.
That is the check that found nine craft in pieces tonight. **A bake that hides the evidence of a broken
aeroplane is worse than no bake.**

This file lives in `cockpit/research/` beside the CL-415 search because every number in it comes from
cockpit's craft, renderer and probes. The probes that produce every number below are
`tests/bake_shot.gd` (windowed; it renders, counts and times) and `tests/bake_survey.gd` (headless; it
counts the tree). Both are listed as probes in `tests/docs.gd`, not as suites.

---

## 1. What already exists, and where the baking stops

| Object | How it is drawn today | Draws |
|---|---|---|
| Air base, every hangar and revetment | `AirbaseView`: one MultiMesh of coloured unit boxes for all the structures, one for the ground, one merged roof mesh | 3 for the whole base |
| Hangar 03 | `SkyfrontHangar`: "ONE WELDED MESH, ONE MATERIAL", one `SurfaceTool` | 1, plus light strips and two labels |
| Towns | `TownView`: MultiMesh, 377 buildings | a handful |
| Cooling tower (`lane/cooling`) | 840 triangles in one surface | 1 each: copies, not pieces |

`modelling_here.md` section 5 is already the house rule: *"One mesh per thing, appended into one
`SurfaceTool`."* The many-pieces case is the **craft**. Craft are built at runtime by
`VehicleView.setup` and the airframe builders as named `MeshInstance3D`s, one per part: `named_parts`
requires that. Moving surfaces are nodes pivoted on their hinges (`SkyhawkAirframe._hinge` / `_swing`).

The survey, built from outside the craft as a player sees it:

| Kind | Instances / surfaces as parts | Cast: instances / surfaces | Materials → after flattening | Pour | Pose, nothing moving |
|---|---|---|---|---|---|
| gunship (AC-130) | 66 / 66 | 4 / 7 | 5 → 5 | 51.2 ms | 66 µs |
| uh60 | 53 / 53 | 2 / 7 | 5 → 5 | 23.5 ms | 55 µs |
| heli | 38 / 38 | 4 / 9 | 5 → 5 | 19.0 ms | 36 µs |
| airliner | 37 / 37 | 4 / 8 | 5 → 5 | 19.4 ms | 36 µs |
| mercury | 34 / 34 | 4 / 9 | 5 → 5 | 33.7 ms | 48 µs |
| tank | 33 / 33 | 1 / 2 | 4 → 2 | 18.5 ms | 34 µs |
| pirate | 32 / 32 | 2 / 9 | 12 → 9 | 12.4 ms | 33 µs |
| chinook | 25 / 25 | 3 / 4 | 2 → 2 | 13.4 ms | 24 µs |
| plane | 24 / 24 | 4 / 8 | 5 → 5 | 14.6 ms | 23 µs |
| osprey | 21 / 21 | 3 / 4 | 2 → 2 | 9.7 ms | 21 µs |
| tanker | 21 / 21 | 4 / 8 | 3 → 3 | 12.9 ms | 21 µs |
| **cessna** | **18 / 18** | **4 / 5** | 2 → 2 | 14.1 ms | 16 µs |
| gunboat | 18 / 18 | 3 / 3 | 3 → 2 | 14.1 ms | 18 µs |
| fighter | 16 / 16 | 4 / 6 | 3 → 3 | 16.2 ms | 14 µs |
| train | 15 / 15 | 1 / 1 | 3 → 1 | 9.5 ms | 15 µs |
| glider | 14 / 14 | 4 / 6 | 3 → 3 | 5.7 ms | 13 µs |
| carrier | 10 / 10 | 3 / 3 | 3 → 2 | 16.7 ms | 10 µs |
| car | 9 / 9 | 1 / 2 | 4 → 2 | 5.4 ms | 9 µs |
| hawkeye | 6 / 6 | 3 / 3 | 1 → 1 | 7.8 ms | 7 µs |
| pod, battleship, tower, segway, boat, submarine | 2–4 each | 1–3 | — | 1–18 ms | 2–4 µs |
| **fleet, 25 kinds** | **508 surfaces** | **117** | | | |

**Of the 117**, 105 are the castings' own surfaces, which is to say the airframes, and **12 are
nav-light MultiMeshes**, one per lit craft. Stations and desks are not in this table: `setup(0, kind)`
builds the craft as seen from outside. The survey ran headless on the double editor with the processor
at 1 per cent. The pour and the pose are GDScript, so read them as sizes, not budgets.

**The floor is the material count, not the part count.** A surface is a draw, and parts share a
surface only if they share a material instance **and** an instance's draw settings. Shadow casting and
a visibility range belong to the instance. What stops a craft reaching one surface:

- **glass**, which is transparent and sorts on its own;
- **shadowless or distance-culled details**, which need their own instances;
- **ships**, whose near model and silhouette differ by visibility range: carrier 10 → 3, battleship
  4 → 3. They were already welded by `ShipHull`;
- **the pirate**, with 12 materials, 9 of them different in more than colour.

---

## 2. Two things the renderer's counter does not say, and why every figure is renderer-dependent

**On Mobile, cockpit's renderer, `DRAW_CALLS_IN_FRAME` is the number of visible INSTANCES.**
`render_forward_mobile.cpp:947` sets it to `p_render_data->instances->size()`. Mobile issues one draw
per surface of every visible instance and never merges repeats. The file has no repeat logic at all.

- **The real Mobile draw count is the number of surfaces.** A multi-surface casting is under-reported:
  the hangar's first casting kept its 8 colours as 8 surfaces, and the counter read **1**.
- **Mobile's shadow figure is ASSIGNED, not summed, per shadow pass** (`:1600`). With cascades it
  reports only the last one: the Cessna's shadow draws read 0 on Mobile and 28 on Forward+.
- **Forward+ counts real draws** and folds consecutive identical surfaces into instanced draws
  (`render_forward_clustered.cpp:875-893`).

**So a draw count here is a fact about one renderer, not about the game.** The cooling towers are 20
real draws on Mobile, the renderer the headset ships on, and would batch on Forward+. Every "N draw
calls" figure in this workshop measured on Mobile with that counter is an object count: exact for
one-surface meshes, low for everything else. This file reports the counter, the surfaces it counted
itself, and Forward+'s counter. It counts shadows on Forward+ only, and trusts the timings above all
three.

---

## 3. The measurements

All windowed, in a bare room (a floor, a sun, flat ambient), on the double editor, RTX 5080, D3D12.
Both views were built by `setup(0, kind)`. Each cost is shown minus the empty room, averaged over 60
frames. Pictures were taken from the same camera, with each view photographed alone.

### The Cessna 172S

| | Parts | Cast |
|---|---|---|
| Mobile, surfaces drawn (the real draw count) | **18** on 18 instances | **5** on 4 instances |
| Mobile counter (instances) | 18 | 4 |
| Forward+ counter, no shadows | 19 | 6 |
| **Forward+ counter, with shadows** | **47** (19 camera + 28 shadow) | **9** (6 + 3) |
| Triangles | 2,896 | 2,896 (checked equal, poured against cast) |
| Craft and shadow pixels that differ, neutral, two cameras (Mobile, shadows) | — | 418 of 112,917 (0.37%, a propeller edge); 0 of 105,694 |
| Same, flown | — | **0 of 112,510; 0 of 107,580** |
| Same, 100 km out on the double build (no shadows) | — | 1 of 69,286; 0; 0; 0 |
| Pour | — | 10.8–17 ms |

**How the surfaces were driven: through the real path.** A server `CockpitWorld` and a client
`CockpitWorld` run over a loopback (`tests/skyhawk.gd`'s own loop), with a pilot in a Cessna at
1,500 m. Over 260 ticks the pilot works throttle 0.7, pitch 0.6, roll −0.4 and rudder 0.5, plus both
flap notches through `send_command(FLAPS, …)`. Each tick, both views are handed the client's bus and
linkage through `VehicleView.draw_the_skyhawk_from`. The parts' trailing edges swung 0.28 m (flaps),
0.16 m (elevators), 0.04–0.05 m (ailerons) and 0.03 m (rudder). **In the engine's own skinning of the
cast view** (`bake_mesh_from_current_skeleton_pose`), every one is **0.0000 m** from its part's.

**Mutants, one per check:**
- **Freeze the pose after the pour.** The flown pictures go red at 13.25% and 5.79% of craft pixels,
  and the trailing edge is 0.28 m out on `FlapPort`. The neutral pictures stay green, as they should.
- **Write the flattened colour as linear instead of sRGB.** 99.96% of the hangar's pixels go red.

### The air base hangar, authored as boxes

The west hangar on `fighter_base` is built from the game's own `AirbaseView.structure_pieces`, not
retyped. It is 58 box nodes, one `StandardMaterial3D` per colour and 8 colours, which is what a
building made in the editor looks like. The pitched roof is left out: it is already one mesh.

| | 58 box nodes | Cast | The game's MultiMesh |
|---|---|---|---|
| Mobile surfaces drawn | 58 | **8 without flattening, 1 with** | 1 |
| Forward+ counter, with shadows | **99** (58 + 41) | **2** (1 + 1) | 2 |
| Triangles | 696 | 696 | 696 |
| Pixels that differ, two cameras | — | 0 of 297,187; 0 of 183,165 | — |

**For a building, a casting reaches exactly what the game's MultiMesh already reaches.** Flattening
lives happily with the faceted look, because the look already lives in vertex colour
(`AirbaseView._vertex_colour`): a flattened material is the same `vertex_color_use_as_albedo` +
`vertex_color_is_srgb` material the base already uses.

### Timing: 100 Cessnas, parts against cast

The run used a MEASUREMENT hold on the GPU slot, no other Godot running and the processor at 1 per
cent. The probe was `bake_shot --many=100 --shadows`: vsync off, 6 pairs, the order alternated
(parts first on even pairs), 60 frames a side after 20 to settle. Each figure below is the cast set
minus the parts set.

| | Wall time a frame | Render CPU | Render GPU | Posing (GDScript) |
|---|---|---|---|---|
| Mobile, shadows | **+2.550** (+2.480 to +2.896) | +0.089 (+0.034 to +0.197) | +0.025 | +1.917 |
| Forward+, shadows | **+3.066** (+2.924 to +3.401) | +0.067 (−0.002 to +0.243) | +0.056 | +2.301 |
| Mobile, shadows, **never posed** | **−0.309** (−0.416 to −0.190) | −0.211 (−0.317 to −0.163) | −0.003 | 0 |

All figures are ms a frame for 100 craft: the median of six pair differences, with the spread in
brackets. Every pair agrees on the sign. Absolute values: parts, Mobile, 0.96 ms wall and 0.54 ms
render CPU. The posed cast set also costs about 0.6 ms of wall time beyond its GDScript loop. That is
the engine updating 100 skeletons and their skins, and it is absent when nothing is posed.

### What a Cessna with its cabin draws

`bake_shot --preview` builds the craft as `fighter_inspector_shot` did, which is where the first figure
of "+76 draw calls" came from:

| Part of the view | Surfaces |
|---|---|
| Airframe (the visual scene) | 17 |
| Nav lights (one MultiMesh) | 1 |
| Station 12, Pedals 10, ConsoleFlaps 10, Yoke 6, MapScreen 6, Trim 6, Shell 4, Button 4, CentreThrottle 3, labels 2 | **59** |
| Total | 77 |

On Forward+ with shadows that is 78 camera draws and **142 shadow draws**, 220 in all. The cabin's
meshes are never poured: they belong to controls and stations that change their own meshes as they
are worked.

| Change | Draws, Forward+ with shadows |
|---|---|
| none | 220 (78 camera + 142 shadow) |
| pour the airframe | 182 (65 + 117) |
| cabin meshes stop casting shadows (`--unshadow-only`) | **106** (78 + 28) |
| both (`--cabin-unshadowed`) | **68** (65 + 3) |

---

## 4. The design

`Casting.pour(root)`, in `objects/casting.gd`:

1. **Every visible `MeshInstance3D` under the root is poured**, unless it is inside a
   `VehicleControl`, `CockpitStation` or `CockpitShell` (the owners `tests/drawn_parts.gd` stops at),
   or hidden when poured.
2. **Each part becomes one bone.** Its triangles are stored in the root's frame at the pour pose,
   weighted 1.0 to that bone, and bound with the inverse of that pose.
3. **Parts are grouped by instance settings** (shadow, visibility range) into instances, and by
   material into surfaces. Albedo-only materials fold into one, with the colour in sRGB vertex colour.
4. **Every frame, each bone is posed to its part**: the part's transform relative to the root, or
   scale zero if the part is hidden.
5. **The parts stay in the tree** on render layer 0 with their shadow off. They are still visible,
   still named, and still what every airframe setter and every geometry suite touches.

### When does the bake happen? At load, and not on disk

| When | Cost | Fits here? |
|---|---|---|
| **Load time, at the end of `VehicleView.setup`** | 1–51 ms per craft, once; nothing to invalidate | **Yes.** Craft are procedural, built from `Sim.geometry_of` and GDScript, and a pour is as current as the build it follows |
| Editor time, `@tool` or a headless tool writing a `.res` | Saves the pour; needs a cache key | No: see below |
| `EditorScenePostImport` | Works for an imported `.glb` | Only when a hand-made asset replaces a builder through `ModelAssetDefinition`. That path is designed and unexercised |

**The cache key is the problem with doing it on disk.** The only honest key for a procedural craft
is a hash of what it builds. Getting that means running the build, and at that point pouring costs the
same 10–20 ms. A key made of inputs (`craft.json`'s hash, as `generate_authored_packages` does) misses
the code: an edit to `skyhawk_airframe.gd` changes the Cessna with its package untouched. **"Changes
are easy since it rebuilds" is answered by storing nothing**: the pour runs on every build and cannot
be stale.

Many craft of one kind could share one pour's `ArrayMesh` and `Skin`, with a `Skeleton3D` each. This
was not built.

### How are "separate, animatable" parts declared? They are not

Every part gets a bone, and the casting copies what the pattern's nodes do. **The list of parts that
move is `set_flaps` and its siblings, which already exist** (CLAUDE.md rule 4). Three rules replace a
declaration:

- **Hidden when poured, left out**, drawing itself if ever shown: the propeller disc.
- **A part whose mesh or material changes leaves the casting**, so it can never show a stale picture.
- **Inside a control, a station or a shell, not poured.**

**This is also what makes it slow**: every bone is posed every frame whether or not anything moved.
Section 6 has the two ways out, and what each costs.

### Pivots and hinge axes

They are preserved by not being touched. The flap's node is still pivoted on its hinge and `_swing`
still turns it, and the bone copies the node's resulting transform. Measured at 0.0000 m.

### Vertex colour

It is preserved as poured, which keeps the Cessna pixel-identical. Flattening writes albedo (sRGB)
times vertex colour back as sRGB; the linear-write mutant shows the trap is real.

### Collision

A casting touches only `MeshInstance3D`s. `pouring_changed_nothing_the_simulation_owns` compares
`Sim.geometry_of(kind)` before and after, and it passes.

### The double-precision build

A casting's vertices are in the root's frame and its bones are relative to the root. Nothing is placed
in world space or read from `CAMERA_POSITION_WORLD`. At 100 km out the pictures agree as they do at
the origin. **This was not tested in a headset, or at 1,000 km.**

---

## 5. What a casting breaks, measured

**A part built adrift and then poured is hidden from `DrawnParts.adrift`.** The casting's box contains
the stray part, so the stray joins the aeroplane through it. A strut built 6 m low was found adrift
**0 times with the casting walked and once with it skipped.**

A part moved **after** the pour is still found, because `adrift` reads a casting's vertex *arrays*,
which hold the pour pose. That is a second hazard: any check reading a casting's arrays sees the
aeroplane as built, not as drawn.

So before castings ship, `DrawnParts.adrift`, `DrawnParts.count` and `named_parts` must skip every node
carrying `Casting.CAST_FROM`. **What a casting does not copy from a part:**
`GeometryInstance3D.transparency`, instance shader parameters, `sorting_offset` and per-part `layers`.

---

## 6. Recommendation

1. **Do not pour craft as the code stands.** It costs about 25 µs a craft a frame and saves about 3 on
   this machine.
2. **Switch shadow casting off on cabin meshes**: the controls, stations and shells a pilot sits among.
   It is 114 of 220 draws on a Cessna with its cabin, and one property per mesh. **Look from the seat
   first**: a yoke's shadow on the panel may be worth its draws in a headset.
3. **Instance repeated buildings** (the cooling towers) with a MultiMesh. Mobile will not batch them.
   Do not "bake" buildings: they are already one mesh or one MultiMesh.
4. **Keep `Casting`** for when posing is cheap. Two ways, neither built:
   - pose only when the airframe announces a change. `draw_the_skyhawk_from` knows when the bus or the
     linkage moved, but that brings back a list of what moves, so weigh it against rule 4;
   - pose in C++.

   The never-posed −0.31 ms per 100 craft is the most either can win on this machine.
5. **If castings ever ship — a hard precondition, not a nicety:** the `CAST_FROM` guard (section 5) in the same commit, and turn
   `bake_shot`'s pixel comparison into a suite over every kind. That comparison caught both of this
   lane's own bugs: a casting that drew nothing, and a camera photographing an empty room.
6. **Stop quoting the Mobile counter as draw calls.** Count surfaces, or measure on Forward+.

---

## 7. What this did NOT establish

- **A headset-class GPU.** Everything was timed on an RTX 5080 under D3D12, where a draw is cheap. On
  a Quest-class GPU the saving per draw is larger and the sign may change. That is not measured.
- **The cabin shadow switch from the seat.** From outside it changes 1.2 per cent of pixels; from
  inside, nobody has looked.
- **The engine's own skeleton-update cost, isolated.** About 0.6 ms per 100 posed craft, inferred from
  wall time minus the GDScript loop, not measured directly. GPU skinning was small: +0.025 ms (Mobile)
  and +0.056 ms (Forward+).
- **Culling.** A casting is culled as one box, so a craft half off-screen draws all of it. Not measured.
- **Sharing one pour across craft of a kind**, and posing only on change: neither built.
- **The Linux machine**, and any renderer other than Mobile and Forward+ here.
