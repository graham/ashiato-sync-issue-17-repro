# Fireboat visual reference — the FDNY *Three Forty Three*

The runtime model is an original procedural one built from the simulation's parts and flat plate
(`objects/vehicles/ships/fireboat.gd`, class `Fireboat`, and `fireboat_shape` in
`ashiato-gd/src/cockpit/cockpit_world.cpp`). **It contains no downloaded mesh, photograph, texture,
trademark or livery.** Added by `lane/fireboat` on 2026-09-19, asked for by the user:

> *"We need a firefighting boat, with a controllable hose that shoots a stream of water (like the
> contrails but better). Look online for fire fighting boats that fight fires and what the water gun
> looks like, it will have at least 2 pilots and 3 water hoses, 2 in front and one in back. Do a high
> fidelity version of this model, it will be up close so it should have lots of detail, even if the
> primatives are 'lower poly'."*

## The word is MONITOR

A fireboat's "water gun" is a **monitor**, also a *deluge gun*, or a *water cannon* in plain speech.
A hose is the flexible thing a firefighter carries; a monitor is the trainable, elevatable nozzle
bolted to the deck or the mast, and it is what the request describes. The code says `Monitor`
throughout, because the house style names classes after physical objects.

## Which boat, and why this one

The **FDNY *Three Forty Three*** (Marine 1, Eastern Shipbuilding, commissioned 2010-09-11): the
archetypal modern big pumping fireboat, red over white, with a raised mast monitor.

She was chosen over the **LAFD *Warner L. Lawrence*** on source quality, not on looks. The Lawrence
publishes a `depth` figure, which is rare and valuable, and her tall mast monitor is much
photographed — but **she has no Wikimedia Commons category at all**, so her layout could never be
measured, only guessed. The *Three Forty Three* has a category of 26 files including a whole-boat
profile. Damen's fire-fighting vessels were also considered because Damen publish general
arrangement drawings with a stated scale, which is the best kind of source there is; none was
found for a dedicated fireboat.

## The published figures

**[W]** Wikipedia, "Three Forty Three", the infobox, read through `action=raw` on 2026-09-19.

| figure | published | the shape (`fireboat_shape`) |
|---|---|---|
| length overall | 140 ft = 42.67 m | 42.68 m (hull part, stem to transom) |
| beam | 36 ft = 10.97 m | 10.98 m |
| draught | 9 ft = 2.74 m | 2.74 m (hull part's bottom under the design waterline) |
| tonnage | 500 **GT** | **not used as a mass** — see below |
| speed | 18 kn = 9.26 m/s | through the helm; `tests/handling.gd` |
| power | 4 × MTU 2,000 hp = 5.97 MW | thrust derived from it — see below |
| propulsion | 4 × Hundested variable-pitch propellers | four raked stacks drawn, one per engine |
| crew | 7 | **5 seats**: helm, second helm, and one operator per monitor |
| pumping | 20,000 gpm, 50,000 gpm max | not modelled as a rate; the monitors either flow or do not |
| monitors | **11** remote control | **3**, as the user asked — see "What is not the real boat" |

### The mass is not 500 tonnes, and the trade press says it is

The infobox field is `{{GT|500}}`. **Gross tonnage measures internal volume, not weight**, and the
trade press ("weighs 500 tons") has read one as the other. That is `modelling_here.md` §2's datum
rule: a real figure quoted against the wrong property of the object.

An independent estimate with nothing of the first in it: `L × B × T × Cb` at `Cb = 0.42` for a
semi-displacement hull doing 18 kn gives 538 m³, about **552 t**. The press figure lands within 10
per cent of that by coincidence of arithmetic rather than by being the same quantity.

**The shape uses 500,000 kg tagged [E]**, with both derivations written down, and never [W].

### Two numbers derived from published figures rather than scaled off another boat

- **Thrust, from the published power.** 5.97 MW at the published 9.26 m/s with a propulsive
  efficiency of 0.55 [E, the usual figure for a workboat on open propellers] is `P·η/v` = **355 kN**.
  The "4 × 2,000 hp" was otherwise an unused printed figure, and a source that gives you six numbers
  has given you six constraints.
- **Hull speed, from the published length.** `hull_speed_for(42.67 m)` — 1.34·√(140 ft) in knots —
  is **8.16 m/s**, and she is published at 9.26. So she runs about 13 per cent *past* hull speed,
  which is what a semi-displacement hull with four engines in it does. This is a **cross-check, not
  a coincidence**: a pure displacement boat of this length could not be an 18-knot boat.

## The layout, measured

**[M]** `Peter Stehlik - FDNY Three Forty Three - 2012.05.17.jpg`, Wikimedia Commons,
**CC BY 3.0 + GFDL 1.2+**, 5,184 × 3,456. A whole-boat port profile underway on the Hudson, with
stem, transom and waterline all in one frame — **and the name legible on the hull, so it identifies
itself.** A caption corrected from the ship, not from another caption.

`measure_boat.py` beside this file re-derives everything below **from the photograph alone**, with
no figure typed out of this write-up, and prints its residuals. `overlay.py` beside it lays the
model's orthographic elevation over the same photograph at the same px/m, which is the only
instrument that can check a fore-and-aft STATION -- **and it does not work yet**, see
`todo/fireboat--the-orthographic-overlay-does-not-scale.md`. Fetch the image from Commons and
put it beside the script; it is deliberately not committed.

```
SCALE      71.3 px/m        one pixel = 14.0 mm        +/- 1.4 %
```

| feature | measured | in the shape |
|---|---|---|
| stem | x = 348 px, ± 4 | z = −21.34 m |
| transom | x = 3,390 px, ± 40 | z = +21.34 m |
| deckhouse | z −7.4 to +0.4 m | −7.4 to +0.4 |
| wheelhouse | z −7.4 to +0.4 m, raised | −7.4 to +0.4, on the deckhouse roof |
| machinery casing (red) | z +0.4 to +5.3 m | +0.4 to +5.3 |
| after deckhouse | z +6.0 to +14.5 m | +6.0 to +14.5 |
| freeboard, forward | 2.88 m | deck 2.40 m + 0.50 m of sheer at the bow |
| freeboard, aft | 2.25 m | 2.40 m |

**The casing's extent is the cleanest measurement on the photograph** — red against white, 300 rows
against 30 — and it is what places the stacks.

### A measurement that was read as the wrong object, and what caught it

The white pixels from z −17 to −8 were first read as a **lower deckhouse** running forward to z −15,
and the model was built with one. It is not a deckhouse. It is a **white bulwark** — a breakwater
round an open foredeck — and the boat's name is painted on the **red topside below it**, not on a
white house. The two forward monitors stand on that open deck.

**Nothing in the measurement could have caught it**, because the pixels really are white and really
are above the deck edge; the scale was right and the extent was right and the *identification* was
wrong. What caught it was `tests/ship_models.gd` reporting that neither helm could see the deck
ahead — twice, once after the house had been "fixed" by stepping it down. The second failure is the
one that mattered: it sent me back to the photograph instead of to the arithmetic.

`modelling_here.md` §3 says a feature you cannot identify cannot be measured however good the scale
is. This is the same rule with the failure hidden: the feature was measured *confidently* and named
wrongly, and only a check that asked a question about the BOAT — can the helm con her? — could tell.

### A cross-check nothing was fitted to

Measured freeboard amidships (2.23 m) plus the **published** draught (2.74 m) gives a moulded depth
of **4.97 m**, and `depth / LOA = 0.117`, inside the 0.10–0.14 a workboat of this length runs.
Measured in, published out. The script prints it and will say `OUTSIDE -- go and look` if it fails,
which it did on the first run and which is the only reason an 8.6 m freeboard did not reach the model.

### Where the helms sit is set by the window sill, not by elbow room

Both helms sit **0.60 m abaft the wheelhouse's front bulkhead**, and that number is not a guess at
comfort. An eye sits `EYE_HEIGHT` above the room's floor and `Wheelhouse.SILL` is 0.95 m above the
same floor, so **the eye clears the sill by a fixed 0.40 m however the wheelhouse is placed** —
raising the room raises both. The only lever on how far down the boat can be conned is how close
the helm sits to the glass.

At 1.10 m back, the line to the deck ahead grazed the top of the sill exactly and `ship_models`
failed it from both seats. At 0.60 m it clears by 0.20 m, which survives that check's own leaning
eye of ±0.05 m. It is also where a helm really stands in a wheelhouse — at the front windows with
the console under them — rather than a metre back as though this were a flight deck.

### Heights above the deck are ESTIMATES, and here is why they have to be

**The superstructure is white and it stands against the Manhattan skyline, which is the same tone.**
A colour detector reads a skyscraper as a deckhouse and returns a 10 m one. `modelling_here.md` §3:
a feature you cannot separate from its background cannot be measured however good the scale is —
the scale here is excellent and the subject is still not separable.

So the deckhouse at 2.80 m, the wheelhouse at 3.00 m, the casing at 4.20 m and the stacks at 2.60 m
are [E], reasoned from ordinary deck heights and checked by eye against the profile.

**What would satisfy the gap:** Eastern Shipbuilding's general arrangement, or any profile of her
taken against open sky or water rather than against a city.

### And a confound that cannot be resolved from one photograph

The fitted waterline falls **1.53 m** from stem to transom and the freeboard falls **0.63 m** aft.
Three causes are entangled and one photograph cannot separate them: the view not being exactly
abeam, the boat's trim, and **the bow wave**, which she certainly has because she is underway.

Worse, the two indicators disagree about which end is nearer. A person on the foredeck reads about
77 px/m against the hull's 71, which says the bow is nearer; the waterline slope read as obliquity
alone says the stern is. **At most one of them is measuring obliquity, and the bow wave explains the
waterline reading on its own.**

So the waterline slope is **not** evidence about heading, and **0.63 m of sheer is an upper bound,
not a measurement.** This is the worst case `modelling_here.md` §3 names: an error that mimics a
feature the thing genuinely has, so the model comes out looking better for being wrong. The model
draws sheer because the boat has sheer; it does not claim that figure as measured.

## The other references, all study only

| Commons file | author | licence | what it gave |
|---|---|---|---|
| `FDNY Marine Division Fireboat, Three Forty Three (50563909328).jpg` | Billie Grace Ward | CC BY 2.0 | The forward monitor group at two deckhouse levels, the wheelhouse front, mast and radomes, caged ladder |
| `... (50563953823).jpg` | Billie Grace Ward | CC BY 2.0 | The superstructure silhouette and the four raked stacks |
| `... (50564652576).jpg` | Billie Grace Ward | CC BY 2.0 | The articulated boom monitor, liferaft canisters, and the red water mains with flanges and valve wheels |
| `... (50564789117).jpg` | Billie Grace Ward | CC BY 2.0 | The stern: aft monitors, transom name board, deck grating, bollards, life rings, RHIB, hose reel, stairs |
| `... (50564789967).jpg` | Billie Grace Ward | CC BY 2.0 | The four stacks in a row and the red casing with FDNY lettering |

**None is incorporated.** They are kept outside the repo, in
`godotgames-drafts/2026-09-19/fireboat/research/`, with this licence table beside them.

### One fact the photographs and the infobox agree on without being asked

The photographs show **four raked exhaust stacks** in a row abaft the wheelhouse. The infobox
independently publishes **four MTU engines**. Two sources that never saw each other, agreeing on a
count — which is the kind of evidence `modelling_here.md` §3 says to go looking for. Those four
stacks are what `Fireboat.exhaust_ports` declares, which is also what keeps `tests/exhaust.gd`'s
ratchet at 29 instead of raising it to 30.

## What is not the real boat

- **Three monitors, where she has eleven.** The user asked for three, two forward and one aft. The
  real arrangement is a group forward on the deckhouse at two levels, a large foredeck monitor, aft
  pedestal monitors and an articulated boom monitor.
- **Five seats, where she has seven crew.** Two helms in the wheelhouse and one operator per
  monitor. The real boat's monitors are worked remotely, mostly from the wheelhouse.
- **No articulated boom monitor, no crane, no RHIB and no diving platform**, all of which she
  carries. They are detail for later, not claims about the ship.
- **The name and the FDNY markings are not drawn.** The model wears the fire-service livery — red
  hull, white upperworks, an orange band — which is generic to the type, and carries no lettering,
  badge or department mark. A livery is a look; a marking is somebody's identity.

## The look, and the segment counts

Faceted and low poly, the Hawkeye's tessellation being the reference. Stated here and in the
model's doc block so nobody subdivides her later (`modelling_here.md` §4, which notes that nothing
enforces this yet):

- hull: **20 stations × 5 rows**, where the warships use 40 stations
- stacks, bollards, the mast: **8-sided**; radomes **10-sided**; stanchions and rails square bar
- every face carries its own normal, so every edge stays hard

**Every vertex colour is at least 0.03 from every other in some channel**, because
`SurfaceTool.commit` quantises colour to eight bits and every geometry check here finds a part *by*
its colour. `RED_FITTING` (0.62) and `HULL_RED` (0.55) differ by 0.07 in red on purpose: a monitor
has to be tellable from the hull it stands on.

## What stays authoritative whatever the model does

The origin, the collision extents, the mass, the seat poses and the parts are `fireboat_shape`'s,
in the simulation. The model draws those parts; it does not decide them. Changing a mesh here can
never move where she floats, where a helm sits, or what she collides with — and
`tests/fireboat.gd` asserts exactly that by taking a deep copy of `Sim.geometry_of` across a load.
