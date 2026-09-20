# Four small craft: two sailing boats, a stern trawler and a 50 ft motor yacht

The runtime exteriors are original procedural models. They contain no downloaded mesh,
photograph, texture, trademark or livery. Each is drawn as the TYPE of boat, with a named real
vessel or production model as its dimensional reference only — no builder's name, sail number,
hull graphic or house style is reproduced.

Four boats share one file because they share one job: they are the craft that make a marina and
a working harbour look inhabited, and they are sized against each other as well as against their
own references.

---

## The four, and what settled each

| | `cruising_sloop` | `classic_cutter` | `stern_trawler` | `motor_yacht` |
|---|---|---|---|---|
| Reference | Bénéteau Oceanis 40.1 | **Leigh 30** (Paine / Morris) | **Ile Vertime** (Socarenam) | Princess F50 |
| Length overall | 12.87 m PUBLISHED | 9.14 m PUBLISHED | 22.50 m PUBLISHED | 15.55 m PUBLISHED |
| Waterline length | — | 7.11 m PUBLISHED | 22.30 m PUBLISHED | — |
| Beam | 4.18 m PUBLISHED | 2.97 m PUBLISHED | 7.90 m PUBLISHED | 4.34 m PUBLISHED |
| Draught | 2.27 m PUBLISHED (deep keel) | 1.40 m PUBLISHED | 3.20 m PUBLISHED | 1.25 m PUBLISHED (full load) |
| Air draught / height | 18.33 m PUBLISHED | 13.10 m ESTIMATE | — | — |
| Displacement | 7,985 kg PUBLISHED (lightship) | 4,128 kg PUBLISHED | 173 UMS PUBLISHED | 23.2 t PUBLISHED |
| Speed | sail | sail | 10 kn PUBLISHED | 34 kn PUBLISHED (top) |
| Designer / builder | Marc Lombard / Bénéteau | Chuck Paine / Morris Yachts | Socarenam, France | Princess Yachts |

### The Leigh 30, and why she is not a second sloop

**Asked for by the user by name, 2026-09-19.** A Chuck Paine design built by Morris Yachts at
Bass Harbor, Maine, from 1979; nineteen were built.
[Wikipedia's article](https://en.wikipedia.org/wiki/Leigh_30) gives the particulars and, more
usefully, the shape: *"raked stem, canoe transom, keel-mounted rudder controlled by tiller"*, a
fixed **long keel with a cutaway forefoot**, high freeboard extended by **bulwarks**, GRP with
wood trim, a **cutter** (Bermuda) rig, and a Westerbeke 13 hp diesel. Sail area 420.27 sq ft
(39.044 m²) total, 195.25 (18.139 m²) in the mainsail and 225.02 (20.905 m²) in the jib; the
foretriangle height I is 36.50 ft (**11.13 m**).

She earns her place by being the **opposite boat to the Oceanis in every respect a viewer can
see**, which is why both are drawn rather than one:

| | Oceanis 40.1 | Leigh 30 |
|---|---|---|
| Stem | plumb | raked |
| Keel | fin, 1.8 m long | long, 4.8 m, cutaway forefoot |
| Rudder | spade, well aft | hung on the keel's after edge |
| Steering | wheel | tiller |
| Stern | transom 3.68 m across, 0.88 of the beam | canoe, 0.36 m across, 0.12 of the beam |
| Deck edge | stanchions and wires | solid bulwark |
| Rig | masthead sloop, one headsail | cutter, two |
| Floats on | very nearly her whole length | 7.11 m of 9.14 |

**The overhangs are a derived figure and a check at once.** LOA 9.14 m against LWL 7.11 m means
2.03 m — more than a fifth of the boat — is stem rake forward and counter aft. The model works
its waterline tuck out of those two published numbers rather than drawing it by eye (split 44 per
cent forward, 56 aft, because a counter overhangs further than a stem rakes), and
`merchant_models` then measures the waterline back off the drawn vertices: **7.07 m against a
published 7.11, 0.54 per cent.** Drawn without it she floated on her whole length and read as a
barge with a mast in it, which is what the first picture showed and no number would have.

**`sailboatdata.com` returns HTTP 403 to an agent** and is on the list with navy.mil and USNI;
the link the user supplied could not be read directly. Wikipedia, Good Old Boat's saildata pages
and Sailboat Guide all carry the same particulars and were readable. Recorded so the next lane
does not spend the attempt.

**The air draught is an ESTIMATE and is the weakest figure on the boat.** No source states height
above the waterline. It is reasoned as the published foretriangle I (11.13 m) plus the masthead
above the forestay and the freeboard under the step, giving 13.10 m. A rig drawing or a bridge-
clearance figure would settle it.

### The trawler, and the one that was rejected

**Ile Vertime**, a 22.5 m stern trawler-seiner built by Socarenam, steel hull with an aluminium
superstructure, shelter-deck design, wheelhouse with 360-degree visibility.
[Baird Maritime's vessel review](https://www.bairdmaritime.com/fishing/fishing-boat-world-reviews/vessel-review-ile-vertime-ultra-modern-22-5m-stern-trawler-seiner-for-france)
gives length overall 22.5 m, length waterline 22.3 m, beam 7.9 m, **draught 3.2 m**, 173 UMS,
Caterpillar 3508C of 561 kW, 10 knots.

**The rejected alternative was Endeavour V**, a 34 m North Sea stern trawler built by Macduff
Shipyards and completed in 2020 (34 m LOA, 10.5 m beam, 4.9 m depth from the main deck and 7.25 m
from the trawl deck, 905 t, Caterpillar-MaK 8M20C of 1,060 kW, 13 knots, full-beam wheelhouse and
twin stern ramps). It is the better-documented ship in every respect **except the one that
decides where the keel goes: its review publishes no draught.** Depth is not draught, and a boat
modelled to a depth floats at whatever height somebody guessed. Ile Vertime publishes both a
draught and a waterline length, so it is the reference; Endeavour V is written down here because
it is the ship the next person will find first, and they should know why it was not used.

Ile Vertime is also the better size for the job — a 22.5 m boat sits in a marina and alongside a
quay, where a 34 m factory trawler is a ship and wants a berth of its own.

### The motor yacht, and two sources that disagree

Two readings of the Princess F50, and they do not quite agree:

| | Length overall | Beam | Draught |
|---|---|---|---|
| Princess's own page / HMY | 15.65 m (51 ft 4 in, incl. pulpit) | 4.3 m | not stated |
| YachtBuyer specification | 15.55 m | 4.34 m | 1.25 m at full load |

The disagreement is 0.6 per cent on length and 0.9 on beam, which is within the difference
between measuring to the pulpit and to the transom, and between the Mk1 and the second-generation
hull. **A single source is a claim, not a fact** — so the model is drawn to the YachtBuyer set,
because it is the only one of the two that states a draught, and the difference is recorded here
rather than averaged away. The length overall including the pulpit is the larger figure and the
model does not draw a pulpit.

### The sloop

Bénéteau Oceanis 40.1, naval architect Marc Lombard, interior and deck by Nauta Design.
[Bénéteau's own specification page](https://www.beneteau.com/oceanis/oceanis-401) gives length
overall 12.87 m (42 ft 3 in), beam 4.18 m (13 ft 9 in), draught 1.68 m shallow and **2.27 m
deep**, maximum air draught 18.33 m (60 ft 2 in), lightship displacement 7,985 kg (17,600 lb),
45 hp maximum engine, CE category A10 / B10 / C12.

**The published draught is to the bottom of the fin keel, not to the hull.** A cruising yacht's
canoe body draws about 0.6 m and the fin carries the rest, so the model draws the hull to
−0.65 m (ESTIMATE, from the hull's own proportions) and a separate fin keel reaching −2.27 m,
which is the published figure. A hull drawn 2.27 m deep would be a boat nobody has ever seen. The
same split is why the keel is its own part rather than a fitting: it is the deepest thing on the
boat and it is what the boat would sit on.

---

## What is PUBLISHED and what is an ESTIMATE

**PUBLISHED** — every length overall, beam and draught in the table above; the sloop's air
draught, lightship displacement and both keel options; the trawler's waterline length, tonnage,
engine and speed; the motor yacht's displacement and top speed.

**ESTIMATE** — the sloop's canoe-body draught (0.65 m) and freeboard; every depth to deck, since
none of the three publishes one; the trawler's shelter-deck height and the height of its
wheelhouse, gantry and mast; the motor yacht's flybridge and windscreen heights; the fore-and-aft
extents of all three deckhouses. No drawing of any of the three looks at them square, and none is
measured here. They are shaped to the published envelope and to each other, and they are the
figures a reader should doubt first.

**Nothing on these four is MEASURED**, and that is worth stating plainly rather than leaving to be
inferred. No three-view, general arrangement or scaled photograph of any of these three was
found that an agent can read, so there is no equivalent of the tanker's photograph work or the
container ships' turning-circle table. Every number is either a published envelope figure or a
proportion reasoned from one.

**Datum and axes:** origin midships on the design waterline, forward −Z, up +Y, starboard +X,
1 unit = 1 m, as every boat here. The simulation's parts stay authoritative for size, collision
and seats; the model draws them.

---

## Outstanding requirements

1. **A general arrangement or profile drawing for any of the three**, which would replace most of
   the ESTIMATE list above with measurements. Sailing-yacht builders publish deck plans and
   accommodation plans freely; a dimensioned profile is the rarer thing and is what is wanted.
2. **A draught for Endeavour V**, which would make the better-documented trawler usable if a
   larger one is ever wanted alongside a quay.
3. **Which Princess F50 generation the figures describe.** The two sources may be describing two
   different hulls rather than disagreeing about one, and nothing found says which.
