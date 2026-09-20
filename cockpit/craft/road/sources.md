# Road vehicles — sources

## The licence line

**The runtime exterior of every road vehicle in this game is an original procedural model, built in
GDScript from the figures below. It contains no downloaded mesh, photograph, texture, trademark,
badge, grille, marque name or livery.** The real types named here are DIMENSIONAL AUTHORITIES and
nothing else: the things in the game are called `hatchback`, `saloon`, `suv` and `pickup`, and no
part of any of them is copied from, traced over, or named after the vehicle that gave it its size.

Study material — three manufacturers' own public specification PDFs — is kept outside the repository
in `godotgames-drafts/2026-09-19/cockpit-roadfleet/research/`, with the full write-up beside it. None
of it is incorporated into the game.

## The axes and the datum

- **Metres. Forward is −Z, up is +Y, starboard is +X**, as everything else in this project.
- **The origin is ON THE ROAD SURFACE, centred along the vehicle's OVERALL LENGTH.** Not the body's
  middle, and not the centre of the wheelbase. Everything that places one of these places it on the
  ground, so a model carrying its own heights in its own frame needs no lift — and a lift is a
  number that ends up typed in two files and disagreeing with itself. `Boxcar`'s origin is on the
  railhead for exactly this reason.
- **Overall length includes the bumpers. Overall width EXCLUDES MIRRORS.** See the warning below.
- The lowest drawn point of every vehicle is the flat at the bottom of its tyres, at y = 0.

## What stays authoritative whatever the model does

Nothing. **These vehicles have no simulation state to be authoritative about** — no kind, no
collision box, no mass, no seat, no socket, no network presence. That is the user's own constraint
of 2026-09-19 and it is the reason this file has no "the simulation owns X" section: there is no X.
The picture is the whole of the thing, and the only contract it has is with this document.

---

## The tags

`modelling_here.md` section 3. **PUBLISHED** — a source states it, named. **MEASURED** — taken off a
reference here, with the method. **ESTIMATE** — reasoned, with what it was reasoned from.

---

## The cars

| | `hatchback` | `saloon` | `suv` | `pickup` |
|---|---|---|---|---|
| authority | VW Golf Mk8 | BMW 3 Series G20 | Toyota RAV4 XA50 | Ford F-150 14th gen, SuperCrew |
| length | 4.284 | 4.709 | 4.635 | 5.885 |
| width | 1.789 | 1.827 | 1.855 | 2.029 |
| height | 1.456 | 1.442 | 1.685 | 1.961 |
| wheelbase | 2.636 | 2.851 | 2.690 | 3.693 |
| tag | PUBLISHED | PUBLISHED | PUBLISHED (but see height) | PUBLISHED (but see configuration) |

Metres. The sources print millimetres and the conversion is exact.

- <https://en.wikipedia.org/wiki/Volkswagen_Golf_Mk8> — 4,284 × 1,789 × 1,456 mm, wheelbase 2,636 mm.
- <https://en.wikipedia.org/wiki/BMW_3_Series_(G20)> — 4,709 × 1,827 × 1,442 mm, wheelbase 2,851 mm.
- <https://en.wikipedia.org/wiki/Toyota_RAV4_(XA50)> — 4,635 × 1,855 mm, height 1,680–1,735 mm,
  wheelbase 2,690 mm.
- <https://en.wikipedia.org/wiki/Ford_F-Series_(fourteenth_generation)> — SuperCrew 5,885–6,185 mm
  long, 2,029 mm wide, 1,920–1,971 mm tall, wheelbase 3,693–3,993 mm.

**TWO FIGURES THE SOURCES CORRECTED BEFORE ANY GEOMETRY WAS WRITTEN.** The lane's own step 0 plan
carried the Golf's wheelbase as 2,620 mm and the 3 Series' height as 1,435 mm. Both were wrong, by
16 mm and 7 mm, and both came from memory rather than from a source. This is what reading the source
first is for, and it is recorded rather than quietly fixed.

### Two published ranges, each resolved by naming a datum

**The crossover's height, 1,680–1,735 mm.** The spread is roof rails and trim, not body. **1.685 m**
is taken: the bottom of the range plus 5 mm. A drawn roof rail is well under a pixel at any distance
these are seen from, and the BODY is what the silhouette is.

**The pickup's length and wheelbase, both ranges, and they MOVE TOGETHER** because they are the
5.5 ft and the 6.5 ft bed. Taking one figure from each end of the two ranges would build a vehicle
that does not exist. **The short bed is taken: 5.885 m on a 3.693 m wheelbase.** Naming the
configuration is the whole of the discipline here — a published dimension has a datum, and a range
is not one.

### Width EXCLUDES mirrors, and this is the trap on the whole lane

Every width above is the body. A large van's mirrors add roughly 350 mm a side; a source quoting the
mirrored width would make one 2.76 m across, wider than the legal maximum for a heavy lorry, on a
van. **So no vehicle here is drawn with mirrors at all** — not for economy but because drawing them
puts the model's own drawn envelope permanently at odds with the source it is checked against, for
two triangles that resolve from nowhere. `RoadCar`'s doc block says the same thing where somebody
changing the model will read it.

### The overhangs

**Front overhang is ESTIMATE; rear overhang is not typed at all.** `RoadFleet.rear_overhang` is
`length − wheelbase − front_overhang`, so the table cannot hold four numbers free to disagree with
one another. A vehicle whose overhangs and wheelbase do not add up to its length is the right size
with the wrong stance, and every dimension check passes.

| | front overhang (ESTIMATE) | rear overhang (derived) |
|---|---|---|
| `hatchback` | 0.875 | 0.773 |
| `saloon` | 0.900 | 0.958 |
| `suv` | 0.960 | 0.985 |
| `pickup` | 0.900 | 1.292 |

Reasoned from body style: a front-drive hatchback carries its engine ahead of the axle and has more
overhang in front than behind; a rear-drive saloon is the other way about; a pickup has a short nose
and a long tail because the bed is the tail.

**THE METHOD IS THE ATEGO'S, AND IT IS WORTH NAMING BEFORE THE LORRY THAT EARNED IT ARRIVES.**
Mercedes-Benz's own specification sheet for the Atego 4x2 rigid gives four wheelbases, four rear
overhangs and four overall lengths — and never prints a front overhang. Subtracting gives **1,620 mm
on all four**, identically. Four independent arithmetic routes to one figure is better evidence than
one printed number, and it is the reason this table derives rather than types.

**AND THE SAME SHEET IS WHERE THIS LANE GOT A FINDING WRONG, WHICH IS WORTH MORE THAN THE FINDING.**
`H` (bumper to back of cab) plus `G` (back of cab to end of frame) falls **180 mm short of the
overall length, on all four wheelbases**. That consistency is real, and this file first recorded it
as a rear underrun bar — concluding, in capitals, that **the body must not be drawn to the overall
length** or it would overhang its own frame. That was written up, reported to the team lead and
endorsed. It is wrong.

**The arithmetic says there is a 180 mm gap. It does not say which END the gap is at**, and the
sheet prints a sixth figure that settles it: `I`, cab rear to front axle, **210 mm**.

| | 180 mm at the REAR | 180 mm at the FRONT |
|---|---|---|
| cab rear, from the front of the vehicle | 1,650 | 1,830 |
| front axle (= derived front overhang) | 1,620 | 1,620 |
| so cab rear to front axle | **30** | **210** |
| printed `I` | 210 | 210 |
| end of frame `= cab rear + G` | 8,885 | **9,065 = the overall length** |

So the 180 mm is a **front fascia standing proud of the bumper datum**, the frame runs the whole
length of the vehicle, and the cab's rear panel is 210 mm BEHIND the front axle — which is what a
cabover is: the cab sits over the engine and its back wall overhangs the axle. The second reading
satisfies every one of the six printed figures; the first contradicts one of them.

**THE LESSON IS `modelling_here.md` SECTION 3'S, MET FROM A NEW DIRECTION.** That section warns that
two independent-looking routes agreeing can make a wrong answer look proved. This was not even two
routes: it was ONE quantity, confirmed four times, and four confirmations of a magnitude say nothing
whatever about its SIGN or its position. **A residual that appears consistently tells you something
is missing; it does not tell you where.** The figure that disambiguated it was sitting on the same
sheet, unused, because the first reading closed plausibly enough that nobody went looking for a
sixth number to contradict it. Use every printed figure, and treat the one you have not used yet as
the check you have not yet run.

### Track — the softest number on the lane, and it is not asserted

Only **one** published track pair turned up for any of these four: a **VW Golf Mk8 GTI at 1,535 mm
front and 1,513 mm rear** against the Golf's 1,789 mm overall width — 0.858 and 0.846. encycarpedia
returns 403 to an agent's fetch, so this is a reading of a search result rather than of the page, and
it is weaker again for that.

So `RoadFleet.TRACK_FRONT_SHARE = 0.855` and `TRACK_REAR_SHARE = 0.845`, **ESTIMATE**, one ratio in
one place carried to three other cars. **It is not a fitted trend and must not be described as one**;
`modelling_here.md` section 3 is explicit that fitting through two ends is how `lane/prowler` lost its
best finding of a morning, and two points are not a trend at all.

**WHAT THE SUITE CHECKS INSTEAD.** Not the number. It checks that the drawn tyres fall **inboard of
the drawn body** and stand under their arches — which catches a wrong ratio in the direction that
actually looks wrong, wheels poking out of the flanks, without asserting a figure nothing published
supports. A check that claimed to know the track to a millimetre would be claiming this document's
weakest sentence as its strongest.

*What would settle it:* a manufacturer specification sheet per type, or a dimensioned front elevation
at a stated scale. The coach and the lorry prove such sheets exist and are readable by an agent.

### Tyres

**The ISO metric formula is PUBLISHED; the fitment is ESTIMATE.** `Pressing.tyre(section, aspect,
rim)` is `rim + 2 × section × aspect`, which is arithmetic nobody need check twice. What has to be
justified is which tyre, and for the cars no source read states the fitment for any particular trim:
these are standard original-equipment sizes for the class and nothing more.

| | fitment (ESTIMATE) | diameter | as a share of overall height |
|---|---|---|---|
| `hatchback` | 205/55 R16 | 0.632 m | 0.434 |
| `saloon` | 225/50 R17 | 0.657 m | 0.456 |
| `suv` | 225/65 R17 | 0.724 m | 0.430 |
| `pickup` | 265/70 R17 | 0.803 m | 0.409 |

**The last column is a cross-check nothing was fitted to.** All four land between 0.41 and 0.46 of
the vehicle's own height, which is where a passenger car's wheel sits; a fitment chosen badly enough
to matter would leave that band. It is a weak check and it is stated as one — a band that wide
rejects a blunder and does not confirm a choice (`modelling_here.md` section 3, the Arleigh Burke's
hull depth).

**315/80 R22.5 is the one PUBLISHED fitment on this lane**, printed on both the Volvo coach's and the
Mercedes lorry's own data sheets. It comes out at 1.0755 m and arrives with the trucks and buses.

### The cabin stations, and the shape shares

All **ESTIMATE**, all shares rather than metres, and all in `RoadFleet.TYPES` and `RoadCar` where the
model can be read beside them. No source read gives any of them; they are what makes a hatchback read
as a hatchback, and they are quoted as fractions of the WHEELBASE measured back from the FRONT AXLE —
a cowl quoted from the nose moves when the bumper changes and the cabin has not.

| | cowl | roof front | roof back | backlight foot |
|---|---|---|---|---|
| `hatchback` | 0.30 | 0.64 | 1.13 | 1.24 |
| `saloon` | 0.34 | 0.65 | 0.95 | 1.09 |
| `suv` | 0.30 | 0.60 | 1.18 | 1.30 |
| `pickup` | 0.23 | 0.48 | 0.78 | 0.82 |

**Those four rows are the whole difference between the four silhouettes.** The saloon's roof stops
at 0.95 wheelbases and falls onto a 0.70 m boot; the hatchback's runs to 1.13 and drops almost
vertically to a tailgate 140 mm from the rear bumper; the crossover's runs furthest and stays high;
the crew cab's stops at 0.86, barely past the rear axle, and a bed follows it.

**THE FIRST DRAFT OF THIS TABLE WAS WRONG AND THE ARITHMETIC CAUGHT IT.** Before any of it was drawn,
each row was put through the four quantities it implies — rear overhang, roof length, windscreen rake
and backlight rake. The hatchback's roof came out ending 35 mm from the rear bumper, and its body
section at the backlight landed 80 mm BEHIND the section after it, which draws a length of body
inside out while leaving the drawn bounds, and so every dimension check, untouched. **Derive the
consequences of a shape table before you build it**; four numbers that each look reasonable can still
describe a car that does not close.

Recomputed, the four rows now give windscreen rakes of 61, 61, 53 and 52 degrees from the vertical
and backlight rakes of 30, 39, 28 and 11 — a real car's screen is 55 to 65 degrees, a pickup's and an
SUV's are more upright, and a crew cab's rear wall is very nearly vertical. None of those eight
figures is typed anywhere; they all fall out of the table.

### The bed, and the one check anchored outside the model

`pickup`'s `backlight` is **chosen so the DRAWN BED FLOOR comes out at the published 5.5 ft**, rather
than typed from a shape that looked right. The cab's rear wall at 0.82 wheelbases leaves **1.6617 m**
of floor between its liner and the tailgate, against a published **1.6764 m** (5 ft 6 in) — 0.87 per
cent under.

That is `Boxcar.SILL_OVER_RAIL`'s method exactly: a soft number set so that a hard one it does not
know about comes out right. `tests/road_vehicles.gd` measures the floor off the DRAWN vertices and
holds it to 5 ft 6 in, and nothing in the model knows the figure exists — which is the only reason
that check can catch anything.

**AND THE FIRST ATTEMPT AT IT WAS WRONG IN A WAY ONLY THE DATUM CATCHES.** `backlight` was first set
to 0.90, on the arithmetic that `tail − backlight` came to 1.6613 m — within one per cent of 5 ft
6 in, and it looked settled. But `tail − backlight` is the bed OPENING plus the tailgate and the rear
bumper standing behind it; the drawn floor at that setting was **1.366 m**, 18 per cent short, and a
pickup with a bed a foot too small would have shipped with a green check over it. **A published
dimension has a datum, and 5 ft 6 in is the floor you can put a pallet on**, not the distance from
the cab to the back of the bumper. It is the same failure `modelling_here.md` records for the 172S's
cabin width: a real number quoted against the wrong place on the object.

`belt` (where sheet metal gives way to glass) and `clearance` (the underside of the body) are typed
in metres per type in `RoadFleet.TYPES`, **ESTIMATE**, reasoned from the type's overall height.

---

## The trucks

### `van` — a large panel van

Authority: **Ford Transit, fourth generation (V363), L3 long wheelbase.**
<https://en.wikipedia.org/wiki/Ford_Transit>

| | figure | tag |
|---|---|---|
| length | 5.980 m | PUBLISHED (the article's long-wheelbase 5,980–6,040 mm) |
| width | 2.052 m | PUBLISHED, **body only** — see below |
| height | 2.550 m | ESTIMATE inside a PUBLISHED 2,088–3,051 mm range |
| wheelbase | 3.750 m | PUBLISHED |
| tyre | 235/65 R16 → 0.712 m | ESTIMATE, a class-standard fitment |

**Width is the trap on this vehicle and it is why nothing on this lane is drawn with mirrors.** The
published 2,052–2,126 mm spread is single against dual rear wheels. A Transit's mirrors add roughly
350 mm a side; quoted as a width that would make it **2.76 m**, wider than a heavy lorry may legally
be. The body is what is drawn.

**The height range spans three roofs** (H1 low, H2 medium, H3 high) and has to be resolved by naming
one. **H2 is taken, at 2.550 m**: the shape that reads as a van rather than as a minibus or a Luton.

### `boxlorry` — a rigid box lorry, 15 t

Authority: **Mercedes-Benz Atego 4x2 rigid, 15,000 kg GVW, model 1524, day cab.** The maker's own UK
specification sheet, kept in the drafts folder.
<https://tools.mercedes-benz.co.uk/current/trucks/specification-sheets/atego/atego-4x2-rigid-1518-1529.pdf>

**This is the best-sourced vehicle on the lane.** Every station is printed or falls out of printed
figures, and the six of them close on one another exactly:

| from the front of the vehicle | mm | where it comes from |
|---|---|---|
| front fascia | 0 | the datum |
| bumper datum (the sheet's `H` is measured from here) | 180 | `cab rear − H` |
| front axle | 1,620 | `D − A − C`, and 1,620 on ALL FOUR of the sheet's wheelbases |
| cab rear wall | 1,830 | `front axle + I`, and `I` is a printed 210 |
| drive axle | 6,380 | `front axle + A` |
| end of frame **and** overall length `D` | 9,065 | they land on the same millimetre |

PUBLISHED outright: `A` wheelbase 4,760; `C` rear overhang 2,685; `D` overall length 9,065;
`G` back-of-cab to end-of-frame 7,235; `H` bumper to back-of-cab 1,650; `I` cab rear to front axle
210; `E` frame height at the front axle 955 unladen; ground clearance front 225; frame width 854;
turning circle 17.6 m; kerb weight 4,432 kg; tyres **315/80 R22.5**, which is the only PUBLISHED
fitment on the lane and converts to 1.0755 m.

**The Atego tops out at 16 t, so this is a 15 t rigid rather than the 18 t first sketched.** A
manufacturer's own closing dimension table for a 15 t lorry beats a broker's listing for an 18 t one,
and from 500 ft nobody can name the difference between a 9.1 m and a 10.6 m two-axle box lorry.

**Height is not typed.** A box body is fitted by a bodybuilder and no maker publishes an overall
height for one, so it is the frame plus the body depth (2.600 m, ESTIMATE) and the suite holds the
DRAWN result under the 4.00 m legal maximum — 3.555 m, with 445 mm of headroom.

**The box body's length is `G` = 7,235 mm, PRINTED**, and that is what the suite holds the drawn body
to. It comes back at 7.235 m to the millimetre.

### `artic` — a tractor unit and a semi-trailer

| | figure | tag |
|---|---|---|
| semi-trailer length | **13.600 m** — "almost all European semi-trailers are 13.60 m" | PUBLISHED, <https://en.wikipedia.org/wiki/Semi-trailer> |
| kingpin from the trailer's front | 1.700 m | PUBLISHED, the standard setting |
| tractor wheelbase | 3.650 m | ESTIMATE, the middle of Volvo FH's published 3,500–3,800 |
| tractor front overhang | 1.450 m | ESTIMATE, from the same family's 5,880–6,180 chassis length |
| fifth-wheel height | 1.150 m | ESTIMATE |
| kingpin set-back from the drive axle | 0.520 m | **DETERMINED — see below** |
| overall combination | 16.480 m | derived from all of the above |

**THE KINGPIN SET-BACK IS A CONSTRAINT, NOT A CHECK, AND THIS MUST NOT BE MUDDLED.** 0.520 m is the
figure that makes the combination 16.480 m and therefore legal — which is exactly how a haulier specs
a tractor, and exactly why **the 16.5 m articulated maximum is a figure this model was FITTED TO.**
It is not quoted as a cross-check anywhere and the suite does not check against it. A check against a
bound you fitted to is the model asking itself a question it already knows the answer to.

**The check that survives intact** is kingpin to the rear of the semi-trailer: a PUBLISHED 13.600 m
trailer less a PUBLISHED 1.700 m kingpin setting is **11.900 m**, against a PUBLISHED 12.500 m
maximum. Published in, published out, with nothing of this lane's anywhere in it.

The suite checks the drawn length against the **18.75 m road-train maximum** instead — nothing was
fitted to that, and it is also the figure that could be read reliably: EUR-Lex's full text through an
agent's fetch conflated the articulated limit with the road train's and returned 18.75 for both.

**Cabover, not an American conventional.** The island's railway is American (an EMD SD40-2 on AAR
track) and a long-nose conventional would sit more happily beside it, but the cabover's length, width
and height are all hard published maxima the drawn model can be held to, and a cross-check nothing
was fitted to is worth more than a stylistic match. A conventional is a bonnet and a different cab on
the same chassis: `todo/roadfleet--american-conventional-tractor.md`.

### Containers, and why none is drawn here

<https://en.wikipedia.org/wiki/Intermodal_container>, all PUBLISHED: the 20 ft dry box is
6.058 × 2.438 × 2.591 m, the 40 ft is 12.192 × 2.438 × 2.591, and the 40 ft high-cube is
12.192 × 2.438 × 2.896.

**Nothing on this lane draws one, on purpose.** The seaport lane is drawing container ships and a
container terminal at the same time, so the box belongs in one place — theirs — and a skeletal
trailer here publishes its DECK (where a box sits, what length fits, how high the deck is) rather
than carrying a copy. One definition, and whoever lands second instances the other's.

**The cross-check that comes with it for free**, and which needs nothing drawn: a **9 ft 6 in
high-cube on a 1.100 m deck stands 3.996 m — four millimetres under the 4.00 m legal maximum.** On a
1.150 m deck it stands 4.046 m and is illegal. That is precisely why low-deck container skeletals
exist, and it means the deck height is not a free choice. A standard 8 ft 6 in box on the same
1.100 m deck stands 3.691 m, with 309 mm to spare.

---

## The buses

### `coach` — a touring coach

Authority: **Volvo 9700, 12.4 m, 4x2, Euro 6.** The maker's own data sheet, kept in the drafts
folder. <https://www.volvobuses.com/content/dam/volvo-buses/markets/master/data-sheets/volvo-9700/Data-sheet-9700-12.4-Euro-6-EN-2022.pdf>

| | mm | tag |
|---|---|---|
| A overall length | 12,400 | PUBLISHED |
| overall width | 2,550 | PUBLISHED |
| C overall height, with AC | 3,650 | PUBLISHED (on 315/80 R22.5, the sheet says so) |
| D wheelbase | 6,170 | PUBLISHED |
| G front overhang | 2,895 | PUBLISHED |
| H rear overhang | 3,335 | PUBLISHED |
| turning radius, outer front corner | 11,148 | PUBLISHED |
| permitted GVW | 19,500 kg | PUBLISHED |

**IT CLOSES: 2,895 + 6,170 + 3,335 = 12,400**, exactly the printed overall length. And the 15.0 m
6x2 sheet in the same family closes the same way with a bogie in it (2,895 + 7,090 + 1,400 + 3,570 =
14,955) **and prints the SAME 2,895 front overhang** — a second, independent confirmation of the one
figure a coach's nose shape depends on most.

`glass_floor` 1.420 m is the **one number that separates this from the city bus**, and it is an
ESTIMATE. No source read gives a coach's window sill height; the 9700's luggage hold is quoted at
7.9–8.8 m³, which over a 2.4 m usable width and roughly 8 m of length between the axles wants very
nearly this much depth. *What would settle it:* a dimensioned side elevation.

### `citybus` — a 12 m low-floor city bus

Authority: **Mercedes-Benz Citaro O530.**
<https://en.wikipedia.org/wiki/Mercedes-Benz_Citaro>,
<https://www.traditionsbus.de/Fahrzeuge/Technik/technik_MB_O530.htm>

**THIS IS THE WORST-SOURCED VEHICLE ON THE LANE AND THE SPREAD IS THE FINDING:**

| source | length | width | height |
|---|---|---|---|
| Wikipedia infobox | 12,135 | 2,550 | 3,130 |
| CPTDB / SGWiki (via search) | 12,135 | 2,550 | 3,120 |
| traditionsbus.de, O530 Technikdaten | 11,950 (12,040 for one batch) | 2,550 | 3,076 (3,318 for another) |

**"A 12 m Citaro" does not name a vehicle.** It is built in several lengths and several roof heights,
and the 185 mm of length and 54 mm of height between these sources is real variation between batches
rather than three people measuring one bus badly. The infobox figure is taken — 12,135 × 2,550 ×
3,120 on a 5,900 mm wheelbase — and the spread is the uncertainty.

**THE WIDTH DOES NOT MOVE: 2,550 on every source.** That is the legal maximum, and a city bus is
built to it. The Volvo coach's own sheet says 2,550 too, from an unrelated manufacturer — **two
makers and the law agreeing on one number, with nothing fitted to it.**

Front overhang 2,700 mm is ESTIMATE, and the rear (3,535 mm) is derived from it. A low-floor city bus
carries its engine behind the rear axle, so the rear overhang is the longer of the two; at 1.31 times
the front, it is.

### The constraint a bus put on the model, which no other vehicle did

**A VEHICLE BUILT TO THE LEGAL MAXIMUM HAS NO ROOM FOR PROUD DETAIL.** The glazing and the skirt were
first drawn 4 mm and 3 mm outside the body's flank, exactly as they are on a car, where nobody
notices. A bus's body is already at 2,550 mm because that is all it may be — so the drawn vehicle
came out **2,558 mm across and illegal**, and the suite said so.

The fix is what a modern bus actually is: **flush bonded glazing sits proud of the pillars and IS the
outer surface.** The body is drawn `GLAZE_PROUD` narrower and the glass sits on the published width,
so the widest thing on the bus is its glass and the drawn envelope is the published figure to the
millimetre. The model and the law agree once it is drawn the right way round.

Every other vehicle here had room to be careless: a hatchback is 1,789 mm wide and no law cares.

---

## The legal maxima — bounds, and which of them anything was fitted to

Council Directive 96/53/EC, Annex I.
<https://eur-lex.europa.eu/eli/dir/1996/53/oj/eng>,
<https://eur-lex.europa.eu/EN/legal-content/summary/authorised-maximum-dimensions-and-weights-for-trucks-buses-and-coaches.html>

| | limit | fitted to? |
|---|---|---|
| maximum width | 2.55 m (2.60 for conditioned bodies) | **no** — checked |
| maximum height | 4.00 m | **no** — checked |
| maximum length, rigid goods vehicle | 12 m | **no** — checked |
| maximum length, two-axle bus | 13.5 m | **no** — checked |
| maximum length, road train | 18.75 m | **no** — checked |
| kingpin to rear of a semi-trailer | 12.5 m | **no** — checked |
| maximum length, articulated vehicle | 16.5 m | **YES** — the artic's kingpin set-back was chosen to satisfy it, so it is NOT checked |

The one row that says YES is the whole reason this table has that column.

**A caveat on the 16.5 m figure itself**, recorded because it is the weakest reading on the lane:
EUR-Lex's full text read through an agent's fetch came back conflating the articulated-vehicle limit
with the road-train limit and reported 18.75 m for both. The 16.5 m comes from secondary readings
(the EESC summary and trade sources) and from the internal consistency of a 12.5 m kingpin-to-rear
plus a tractor's front section. The 2.55 m and 4.00 m figures were read consistently everywhere and
are safe. **The suite checks the figure that cannot be wrong.**

A cross-check that costs nothing: the Citaro's 2,550 mm and the Volvo coach's 2,550 mm, from two
unrelated manufacturers' own sheets, both land exactly on the width maximum. That is the maxima and
the vehicles agreeing.

---

## Still outstanding

Recorded with what would satisfy each, because a stated gap with its remedy is a finding and an
invented number in the same place is a liability.

- **Track, all four types.** One secondary ratio carries them. Wants a manufacturer sheet or a
  dimensioned front elevation at a stated scale.
- **Tyre fitments, all four types.** Class-standard sizes, no source. Wants the same.
- **Front overhangs, the cars.** Reasoned from body style, no source. Wants a dimensioned side
  elevation — and the Atego sheet shows that for commercial vehicles these are derivable exactly.
- **The tractor unit's cab height and fifth-wheel height.** Both ESTIMATE. Wants a Volvo FH or DAF XF
  data sheet of the kind the Atego already gives; those two sheets prove such a thing exists and is
  readable by an agent, so this is a findable gap rather than a hard one.
- **The van's per-variant height.** Wants Ford's own L3H2 sheet rather than the article's range.
- **The box body's depth**, 2.600 m, ESTIMATE. Wants a bodybuilder's specification.
- **The coach's window sill height** (`glass_floor` 1.420 m), reasoned from a published luggage
  volume. Wants a dimensioned side elevation — Volvo publishes one in the same family of documents
  the dimension table came from, so this is findable.
- **The city bus's overhang split**, and which of three published lengths its batch actually is.
