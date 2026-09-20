# CB90 fast assault craft (Stridsbåt 90 H) visual reference

The runtime model is an original procedural one built from the simulation's parts and flat plate
(`objects/vehicles/ships/combat_boat.gd`, class `CombatBoat`). It contains no downloaded mesh,
photograph, texture, trademark or livery. Added by `lane/boats` on 2026-09-18, asked for by the
user: *"a beefier CB90 or other fast assault craft so that we can have a boat with two guns on the
back, maybe a missile launcher as well, that has the same targeting as the plane that has missiles."*

## The figures

**[W]** Wikipedia, "CB90-class fast assault craft", the infobox, read through
`action=raw` on 2026-09-18:

| figure | published | the shape (`cb90_shape`) |
|---|---|---|
| length overall | 15.9 m | 15.90 m (hull part, stem to transom) |
| waterline length | 14.9 m | not modelled separately: the hull part is one prism |
| beam | 3.8 m | 3.80 m |
| draught | 0.8 m | 0.80 m (hull part's bottom under the design waterline) |
| displacement | 13,000 kg empty, 15,300 standard, 20,500 full load | 15,300 kg |
| speed | 40 kn (CB90 HSM 45 kn) | 45 kn class through the helm: see `tests/handling.gd` |
| propulsion | 2 x Scania diesels, 2 x Kamewa waterjets | two waterjet housings drawn on the transom |
| complement | 3 crew, up to 18 troops | 4 seats: helm, weapons officer, two gunners |
| armament | 3 x M2HB, 1 x Mk 19, mines or depth charges; HSM: a Trackfire RWS | 2 x 12.7 mm on the after deck and a missile box on the roof |

[W] also says the Royal Norwegian Navy fired **Hellfire** missiles from a stabilised launcher on a
CB90 in 2004, which is the precedent for a missile box on this boat. The box here carries the
game's own rows because the user asked for the light twin's targeting: heat, and "sea radar", the light twin's radar row
that also locks ships ("not ground targets but ships yes").

## The layout

**[P802]** "CB90-802 Stockholm.jpg", Wikimedia Commons, **CC BY-SA 2.0** (Flickr), 2816 x 2112. The
prototype 802 moored, seen close to broadside from a little above. Measured on the 960-pixel
rendition with the stem at x 830 and the transom at x 125: **705 px for 15.9 m, 44.3 px a metre**,
along the hull at the waterline. It is an oblique view from above, so heights are foreshortened and
only proportions along the hull are taken from it:

| feature | pixels (x) | metres from the stem | in the shape |
|---|---|---|---|
| wheelhouse front | 650 | 4.0 | 3.95 m forward of midships = 4.0 m from the stem |
| wheelhouse back | 470 | 8.1 | 0.15 m abaft midships = 8.1 m from the stem |
| knuckle (where the slab side turns in to the bow) | about 760 | 1.6 | 2.25 m (plan corner at z -5.70); ESTIMATE |

Heights are ESTIMATES: the deck edge 1.0 m over the waterline and the wheelhouse roof 2.1 m over the
deck (the photograph's roof stands about a man's height over the gunwale).

**[P826]** "Stridsbåt 90.jpg", Commons, **CC BY-SA 2.0**, the infobox photograph: 826 at speed in
splinter camouflage, three-quarter from ahead. Used for the look only: the camouflage colours, the
visor over the wheelhouse windows, the rails round the after deck and the bow wave.

**[PFRONT]** "CB90 class fast assault craft Medical Evacuation Event (8462316).jpg", Commons,
**public domain** (US Marine Corps). Head-on: the bow ramp and its hinge line across the whole bow,
the wheelhouse's width against the beam. Look only.

No drawing of the CB90 was found on Commons (searched "CB90", "Stridsbåt 90", "Combat Boat 90",
"Riverine command boat" with drawing, svg, profile and ritning on 2026-09-18), so no plan view was
measured; the plan outline is the published length and beam with the knuckle placed off [P802].

## What is not the real boat

- **Two guns at the back and none on the roof.** The real boat's roof gun or weapon station is where
  the missile box is, because the user asked for two guns at the back and a launcher.
- **The box is raised 11.5 degrees** so its seeker sees aircraft; `Loadout::launcher_pitch`.
- **The troop compartment is drawn as a coaming with two hatches** on the after deck; nobody rides in
  it yet (`kMaxSeats` is four).
