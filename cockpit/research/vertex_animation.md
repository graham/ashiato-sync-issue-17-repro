# Vertex animation textures, and what moves a craft's parts fastest

**The user asked** (2026-09-17): *"learn about vertex animation textures, and determine how they work in godot, I want
to know if we can use vertex animation textures to do things like ailerons, rudders, and other control surfaces, or
gear extending or retracting. It might be the wrong technology, but I think it would be faster than bones+animations
since I think VATs are on the GPU."* Then, the same day: *"VAT is how we will animate all features (control
surfaces, gear, landing hook, wing sweep, etc)"*.

## The answer, first

1. **Yes, a VAT fits, in one form: a rigid-body VAT indexed by each feature's amount, not by time.** It is built
   (`objects/vat_casting.gd`), and it draws the Cessna's surfaces and the fighter's gear and hook where the parts do:
   - Cessna flown through a real server and client: **1 of 112,510** craft pixels differ from the parts, and the worst
     vertex is **0.02 mm** out;
   - fighter, gear and hook through the real draw function: **0** pixels differ, and at in-between gear amounts the
     worst vertex is **0.59 mm** out.
2. **The classic per-vertex VAT is the wrong encoding for these craft.** It stores every vertex's position every
   frame. Every moving part here is rigid, so one transform per part says the same thing in a fraction of the
   texture. What made the user's idea work is keeping the GPU side and changing what the texture holds.
3. **The CPU's job becomes one number per feature, handed over only when it changes.** Nothing is posed and no
   skeleton exists. That is the cost `bake` measured as the whole problem: GDScript posing 17 bones a frame, about
   25 µs a Cessna.
4. **Nothing new is declared except the feature.** The bake calls the airframe's own `set_ailerons`, `set_gear` and
   the rest at each sample, and records where every part went. The fighter's doors-then-legs order, the aileron's
   20° up and 15° down, and the flap's slide aft are in the texture without a line of the VAT knowing them.
5. **It is the fastest option measured when things move, and free when they don't.** 100 Cessnas with every
   surface moving every frame, Mobile with shadows, wall time a frame above the same craft as parts:
   **VAT +0.42 ms**, hinge shader +1.09, bones posed on change +1.67, bones posed every frame (`bake`) **+4.57**.
   Parked, the VAT is +0.08 ms, the same as the parts within the spread. Its texture fetches cost the GPU +0.024 ms
   per 100 craft. Section 5.
6. **Recommendation: the rigid-body VAT, one texture per craft kind, one table per feature**, with the amounts handed
   over from the bus the view already reads. Section 7 has the order of work.
7. **The headset is not measured** (section 6). The reasons to expect the VAT to do *better* there than here are
   in that section, and so is the one thing that could go against it.

---

## 1. What a VAT is

A vertex animation texture stores an animation as pixels, which the vertex shader reads back.

- **Per-vertex (the classic form):** one column per vertex, one row per frame, each texel a position. It is the
  standard answer for crowds and for things that bend (cloth, flags, a soldier's walk cycle baked out of bones). A
  thousand copies in one MultiMesh can each play at their own phase with no skeleton on the CPU.
- **Rigid-body:** one column per *piece*, one row per frame, each texel a piece's rotation and position. Each vertex
  carries its piece's index. Houdini's Labs VAT exporter has both modes.

In both forms the animation is fixed when baked, and the GPU replays it. The frame index usually comes from `TIME`.

## 2. How it is done in Godot 4.7

Godot has no VAT node or importer. It is a `ShaderMaterial` whose `vertex()` does the lookup:

| Need | Godot 4.7 | Notes |
|---|---|---|
| Which vertex, or which part | `VERTEX_ID`, or a tag in `CUSTOM0` | `VERTEX_ID` is fragile: the importer may reorder and deduplicate vertices, and 4.x mesh compression quantises. **A part index baked into `CUSTOM0` survives that**, so the casting uses one (`Mesh.ARRAY_CUSTOM0`, `ARRAY_CUSTOM_RGBA_FLOAT`) |
| Read a texture in `vertex()` | `texelFetch(tex, ivec2, 0)` | Lossless: `Image.FORMAT_RGBAF`, no mipmaps, `filter_nearest, repeat_disable` |
| A per-craft value | `instance uniform vec4`, set with `GeometryInstance3D.set_instance_shader_parameter` | **At most 16 per shader** (`MAX_INSTANCE_UNIFORM_INDICES`, `shader_language.h:351`). Scalars and vectors only |
| A per-copy value in a MultiMesh | `INSTANCE_CUSTOM` (4 floats) plus the instance colour | Not built here |
| Shadows | The same `vertex()` runs in the shadow pass | A lowered flap casts a lowered shadow (seen in `vat-flown-0-vat-cast-shadows.png`) |
| A `StandardMaterial3D` as a shader | See below | |

**Converting a `StandardMaterial3D` from a script.** A VAT needs the part's material as a `ShaderMaterial` with a block
at the top of `vertex()`. `Material.get_shader_rid()` is **not bound to scripts**. The one door is
`Material.inspect_native_shader_code()`: it hands the shader's RID, by a deferred call, to every node in the group
`_native_shader_source_visualizer`. After that, `RenderingServer.shader_get_code(rid)`,
`get_shader_parameter_list(rid)` and `material_get_param` give what the editor's "Convert to ShaderMaterial" copies.
Converted this way, the Cessna draws identical to its parts (0 of 105,550 pixels differ at neutral).
`HingeCasting._shaders_of` does it.

**How bones compare, in the engine as it is.** On Forward+ and Mobile skinning is a compute pass
(`mesh_storage.cpp:1149`), run only for an instance whose skeleton `version` changed (`:1134`). It writes a skinned
copy of the vertex buffer for each instance. So bones were never slow on the GPU. `bake`'s cost was the CPU:
GDScript reading 17 `global_transform`s and posing 17 bones every frame, then `Skeleton3D` pushing them to the server.

**On the double build**, everything here is in the craft's own frame and applied before `MODELVIEW_MATRIX`. Nothing
reads `CAMERA_POSITION_WORLD`. Not tested far out.

## 3. A control surface is not a timeline, so the rows are amounts

| | A VAT's assumption | An aileron |
|---|---|---|
| What drives it | time | the stick, continuously, both ways |
| How many motions at once | one clip | ailerons, elevator, rudder, flaps and trim at once: five on the Cessna |

You cannot bake every combination of five inputs. **But you do not need to: each feature's rows run from its low
amount to its high, and each vertex reads only the rows of the features that move its part.** Five independent
features are five row ranges, each looked up at its own amount. A part moved by two features takes both, inner
first. The Cessna's trim tab turns on trim and rides the elevator. The feature that turns the deeper node of the
part's chain is applied first, and that is the order the node tree composes them in.

**Each feature is its own table, in one texture.** The user asked whether a craft could have several VATs, "that
might let us manage more over time". Each feature has its own block of rows, its own row count and its own start
row. The shader finds them through a small table of contents, the uniform arrays `vat_first[]` and `vat_rows[]`.
The fighter's gear keeps 129 rows for its two-stage sequence, and the hook asks for 33 (hook within 0.38 mm between
rows). Adding or rebaking a feature appends or rewrites its own rows only, because every feature is baked with the
others at rest. **Why one texture and not a texture per feature:**
- **Fetches per vertex:** the same either way, because a vertex reads only the tables of the one or two features
  that move it.
- **Separate textures:** each would cost a sampler (a mobile shader stage has about 16, and the material already
  uses some). They would also cost a branch, because which texture a vertex reads varies per vertex.

**The texture for a Cessna is 16 columns (parts) by 645 rows (5 features x 129 samples), two RGBAF textures:
330 KB.** It is the same for every Cessna, so in a game one bake per kind serves every copy. This proof of concept
bakes one per craft.

### Rows: the one number a VAT adds, measured

Between two rows the shader blends linearly (quaternion `nlerp`, offset `mix`), and that is not exact for a turn
about a hinge away from the craft's origin. The worst vertex anywhere on the craft, by the CPU copy of the shader's
formula (`VatCasting.played_point`), at in-between amounts that are **off the grid**:

| Rows a feature | Fighter main gear door, gear 0.1–0.2 | Fighter main gear, 0.3–0.9 | Cessna, flown |
|---|---|---|---|
| 33 | **9.2 mm** | 3.1 mm | 0.31 mm |
| 65 | 2.2 mm | 0.6 mm | — |
| **129 (default)** | **0.59 mm** | 0.19 mm | **0.02 mm** |

The error quarters when the rows double. The doors are the worst case because `set_gear` makes their whole swing
in the first quarter of the gear's travel (`smoothstep(0.0, 0.25, …)`). So rows spread evenly over the amount waste
most of themselves there. Rows are cheap (32 bytes a part), so 129 is the default. The first version of this check
asked at 0.5 and 0.75, which are rows, and read 0.00000 m: **a blending check must ask between the rows.**

## 4. The candidates

| | Where the work is | CPU a frame, nothing moving | CPU a frame, everything moving | Exact? |
|---|---|---|---|---|
| A. Parts as nodes (today) | one draw per part | none extra | the airframe's setters only | yes |
| B. `Casting`, posed every frame (`bake`) | 17 poses a craft, every frame | ~25 µs | ~25 µs | 0.0000 m |
| C. `CastingOnChange` | the 8 bones on hinges, posed only when a hinge moved | a compare per hinge | 8 poses | 0.0000 m |
| D. Bones posed in C++ | a native loop | small | small | reasoned, not built: the C++ slot is `cl415`'s |
| E. `HingeCasting` | one `vec4` per hinge (angle and slide) on change; the GPU turns vertices about the hinge line | a compare per hinge | 8 `vec4`s | pixel-identical; 0.0000 m by its own formula |
| **F. `VatCasting` (rigid-body VAT)** | one float per feature, four to a `vec4`, on change; the GPU reads two rows per feature | a getter and a compare per feature | 2 `vec4`s | 0.02 mm (Cessna), 0.59 mm (fighter doors) at 129 rows |

**E against F.** They are the same idea with the table and the formula swapped:

- **E is exact and needs no texture**, but only for a part that turns about one fixed line. It needs a record of
  every hinge (`SkyhawkAirframe._hinges`), which the fighter does not have. It also needs one uniform per hinge: the
  Cessna has 8, and a shader may have 16.
- **F handles any rigid motion a setter produces** from one number per feature: a slide, a door that pitches then
  swings, a leg that folds, a wing that sweeps. It needs nothing recorded except the feature itself. Its costs are
  two texel fetches per feature per vertex per pass, and a blending error you choose by the row count.

**For "every feature on every craft by one mechanism", F is the one**, because nothing about it is specific to
hinges.

## 5. Measurements

**How.** `tests/vat_shot.gd --many=100 --variant=<v> [--moving] --shadows`, windowed, double editor, RTX 5080,
D3D12, vsync off. Each run is 100 Cessnas as parts against 100 as the variant, shown in turn, **six pairs with the
order alternated**, 60 frames a side after 20 to settle. Each figure is the variant minus the parts: the median of
the six pair differences, with the spread in brackets. The runs used a MEASUREMENT hold on the GPU slot, 20:04:28 to
20:07:10 on 17 Sep 2026. **No other Godot was running when the first run started** (a `rotors` suite had drained at
20:04:25). Timed at `9cbe7fd9`.

- **Wall** is the frame's wall time.
- **Render CPU / GPU** are the viewport's measured times.
- **Update** is the variant's own GDScript each frame (`pose`, `swing`, `play`).
- **Moving** works every craft's ailerons, elevator, rudder and flaps every frame through the airframe's own setters,
  on both sets. It is the worst case, every surface of every craft changing every frame. Parked, nothing moves.

Parts, absolute: about 1.1 ms wall parked and 2.3 ms moving; render CPU 0.6–0.9; GPU 0.09 (Mobile) and 0.17 (Forward+).

### Parked, Mobile with shadows

| Variant | Wall | Render CPU | GPU | Update |
|---|---|---|---|---|
| B. bones every frame (`bake`) | **+1.839** (+1.744 to +2.558) | −0.004 | +0.001 | 1.803 |
| C. bones on change | **−0.154** (−0.250 to −0.003) | −0.183 | −0.001 | 0.106 |
| E. hinge shader | +0.053 (−0.118 to +0.137) | −0.231 | +0.008 | 0.287 |
| **F. VAT** | **+0.075** (−0.042 to +0.138) | −0.128 | +0.009 | 0.199 |

### Moving, Mobile with shadows

| Variant | Wall | Render CPU | GPU | Update |
|---|---|---|---|---|
| B. bones every frame | **+4.574** (+3.423 to +5.078) | +0.230 | +0.034 | 2.840 |
| C. bones on change | +1.673 (+0.995 to +2.657) | +0.061 | +0.032 | 0.599 |
| E. hinge shader | +1.086 (+0.651 to +1.950) | −0.161 | +0.008 | 0.962 |
| **F. VAT** | **+0.420** (+0.181 to +0.513) | −0.188 | +0.024 | 0.485 |

### Moving, Forward+ with shadows

| Variant | Wall | Render CPU | GPU | Update |
|---|---|---|---|---|
| C. bones on change | +1.388 (+0.497 to +2.036) | +0.021 | +0.063 | 0.601 |
| E. hinge shader | +0.637 (−8.394 to +1.248) | −0.307 | +0.027 | 0.932 |
| **F. VAT** | **+0.229** (−6.328 to +0.701) | −0.319 | +0.031 | 0.504 |

The Forward+ hinge and VAT runs each had a start-up hitch in their first pair: parts 15.8 ms wall against 9.4 in the
VAT run. That is what the huge negative ends of their spreads are. The medians stand, and the spreads should be read
without that pair.

### What the numbers say

- **B is the cost the user set out to beat, and it is 46 µs a moving Cessna.** The GDScript loop is 28 µs of it. The
  rest is the engine updating 100 skeletons and their skins. `bake` measured +2.55 ms parked on its own run; this
  run's +1.84 ms is the same finding.
- **Bones posed on change (C) are the cheapest thing when nothing moves** (−0.15 ms, the merge's saving with nothing
  spent). But the moment surfaces move they cost +1.67 ms, 17 µs a craft. Only 6 of that is GDScript; the rest is the
  engine's skeleton and skin update.
- **The hinge shader (E) moves nothing on the CPU but still pays in GDScript:** 8 `set_instance_shader_parameter`
  calls a craft when all 8 hinges move.
- **The VAT (F) is the cheapest when things move, 4.2 µs a craft.** Nearly all of that is the GDScript in `play`:
  five getter calls and two `vec4`s. The GPU pays 0.24 µs a craft on Mobile. The texture fetches that section 3
  worried about are noise on this GPU.
- **Every casting saves 0.13–0.32 ms of render CPU per 100 craft**: the merge, 18 → 5 draws a Cessna. The GPU time
  barely moves in any variant. **On this machine the whole contest is CPU work.**
- **The VAT's parked +0.08 ms is its per-frame check**, a getter and a compare for each of 5 features on 100 craft.
  It would go if the view handed the VAT the amounts it already reads from the bus.

## 6. The headset: what these numbers do and do not say

**Not measured. Everything here is an RTX 5080 under D3D12.** What should carry over, and why:

- **CPU work matters more on a Quest, not less.** A Quest-class CPU core is several times slower than this desktop's,
  and the headset renders two eyes at 72–90 Hz. GDScript posing that costs 25 µs a craft here would cost several
  times that there. **Approaches that move work off the CPU (C, E, F) should gain more there than here.** B should
  lose more.
- **GPU skinning on a tiled mobile GPU**: a compute pass between render passes costs a barrier and a round trip
  through memory, and each skinned instance keeps its own copy of the vertex buffer. E and F skin nothing and copy
  nothing.
- **The vertex-shader cost of E and F**: a few dozen arithmetic operations (E), or four texel fetches per feature
  (F), per vertex per pass. A Cessna is about 8,500 vertices. Even at 100 craft and three passes (Mobile renders
  both eyes in one multiview pass, plus shadow), that is small next to an Adreno's vertex rate. **Vertex texture
  fetch is the one thing that could be slower than expected on a mobile GPU.** It is supported on Adreno but has
  higher latency than arithmetic. If a headset measurement shows F's GPU time above E's, that is why, and E is the
  fallback for pure hinges.
- **Draw calls cost more on the headset**, so the merge itself (18 → 5 on a Cessna) should be worth more there. That
  is `bake`'s unmeasured case, and it applies to every casting here equally.
- **Shader compilation**: each converted material is a new shader. On a headset that is a pipeline to compile
  before first use, a hitch if it happens mid-flight. One shader per material per kind, compiled at load.

## 7. Recommendation

1. **Animate every feature with the rigid-body VAT (`VatCasting`)**: control surfaces, gear, hook and wing sweep.
   One texture per craft kind, one table per feature, each with its own row count (129 by default; fewer for a plain
   swing).
2. **Each airframe publishes its features**: `{name, set, get, low, high, samples?}` beside the setters they name.
   That is the one list a VAT needs, and the airframe already owns every entry. Today `tests/vat_shot.gd` writes it
   for the Cessna and the fighter.
3. **Hand the amounts over from the bus.** `VehicleView.draw_the_skyhawk_from` already has them. Passing them straight
   to the VAT, instead of the VAT asking the airframe's getters, removes the last per-frame GDScript on a parked craft.
4. **Keep the pattern nodes.** The airframe's setters still turn its nodes, and every geometry suite reads those
   nodes. The VAT is baked from them and never replaces them as the authority.
5. **Bake once per kind at load**, and share the texture and the converted materials across every copy of that kind.
   Not built: this proof bakes per craft.
6. **Before any casting ships, a hard precondition**: `DrawnParts.adrift`, `DrawnParts.count` and `named_parts` skip
   `Casting.CAST_FROM` in the same commit (`static_bake.md` section 5). Also make `vat_shot`'s picture comparison a
   suite over every kind with features.
7. **Do not use the classic per-vertex VAT** for rigid parts, and do not use the hinge shader as the general
   mechanism. It is exact but needs a hinge record per part and one uniform per hinge, and it measured 2.6x the
   VAT's cost when moving.

## 8. What this did NOT establish

- **A headset-class GPU**, above all (section 6).
- **Wing sweep.** It is `tomcat`'s airframe, left to that lane. A sweep is a rigid turn of each wing about a pivot,
  so it is the rigid-body VAT's easy case. Its one catch is that parts on the wing (flaps, slats) would be moved by
  two features, sweep outer and flap inner, which is exactly the trim tab's case. **Since established (2026-09-18,
  `lane/tomcat2`):** the F-14's spoilers are that case, hinged on a child of the wing's pivot, and play through two
  tables, their own inside the sweep's, to 0.36 mm at 65 rows (1.14 mm at 33) and 13 of 185,813 pixels with every
  surface over and the wing at 44 degrees. A lockout that depends on the sweep (spoilers down past 57 degrees) goes on
  the AMOUNT the casting is handed, never into the geometry, so each table stays a function of its own feature alone.
- **Gear over time.** The bus has no in-between for the gear: `vehicle_view.gd` snaps it to 0 or 1. The in-between
  amounts were set with `set_gear` directly. When the simulation owns the gear's travel (`actuators_research.md`),
  the VAT needs nothing new: it is handed the amount, whatever drives it.
- **Visibility.** A feature that hides or shows a part is not baked. None does today.
- **Sharing one bake across a kind**, and a MultiMesh of cast craft: neither built.
- **The drawn-parts checks.** A casting hides a part built adrift from `DrawnParts.adrift` (`static_bake.md`
  section 5). All three castings here carry `Casting.CAST_FROM`, and the same guard is the hard precondition for
  shipping any of them.
- **Culling.** A shader-moved vertex leaves the poured box, so the castings widen it with `extra_cull_margin` (1 m
  and 2 m). That is a guess, not a measured bound per kind.
