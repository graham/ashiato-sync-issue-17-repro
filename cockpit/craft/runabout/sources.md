# A Chris-Craft triple-cockpit runabout: where its numbers and its colours came from

The runtime exterior is an original procedural model. It contains no downloaded mesh,
photograph, texture, trademark or livery. It is drawn as the TYPE of boat — a pre-war American
varnished-mahogany triple-cockpit runabout — with a named production model as its dimensional
reference only. No builder's name, script logo, hull graphic or house style is reproduced: the
gold `Chris★Craft` script on the topsides of every photograph below is a trademark and is not
drawn.

**The subject is the Chris-Craft 27 ft Custom Runabout, model Custom 309, 1932–1941.** It was
chosen over the better known 25 ft Custom Runabout for one reason: it is the only boat of the
type this session could find with a **published beam and draught**. Sixty-two were built
(Sierra Boat Company, below).

---

## 1. The envelope

| quantity | metres | original | tag | source |
|---|---|---|---|---|
| Length overall | **8.230** | 27 ft 0 in | PUBLISHED | [S] |
| Beam | **2.184** | 7 ft 2 in | PUBLISHED | [S] |
| Draught | **0.711** | 28 in | PUBLISHED, **datum unstated** — see below | [S] |
| Length : beam | 3.77 | — | derived | [S] / [S] |
| Top speed | 28–45 mph over the range of models (12.5–20.1 m/s) | PUBLISHED | [SO] |
| Construction | seam-and-batten mahogany over white oak framing; double-planked mahogany with oiled canvas between the skins | PUBLISHED | [S], [SO] |

**THE DRAUGHT'S DATUM IS NOT STATED AND THAT IS THE MOST DANGEROUS NUMBER HERE.** 28 in on an
8.2 m hull whose canoe body is a shallow hard-chine planing form is far too deep to be the
bottom of the planking; it is almost certainly to the bottom of the propeller or the rudder
shoe. `modelling_here.md` section 2 is entirely about this failure — a real figure quoted
against the wrong place on the object — twice, in opposite directions, on a Cessna and on a
car. So it is **not** used as the hull's floating draught.

**What settles it is a second boat neither source set out to compare with.** Wikipedia's
Gar Wood Speedster [GW] — a contemporary American mahogany runabout, a different builder, a
different decade of coverage — publishes 16 ft × 5.4 ft × **1.4 ft draught**. As a fraction of
length:

| | length | draught | draught / length |
|---|---|---|---|
| Gar Wood Speedster [GW] | 4.877 m | 0.427 m | **0.0875** |
| Chris-Craft Custom 309 [S] | 8.230 m | 0.711 m | **0.0864** |

**1.3 per cent apart, from two sources that have nothing to do with each other.** Two
independent references agreeing on a third quantity neither produced is the strongest
arbitration available here (`modelling_here.md` section 3), and what it says is that **both
figures are measured to the same datum** — the lowest point of the running gear, not the
planking. The hull's own floating draught is therefore taken as roughly half of it and is an
ESTIMATE; it is stated as such in `runabout.gd` and nothing is checked against it.

### The length-to-beam trend, and what it rejected

Three published pairs, three sources, three boats:

| boat | length | beam | L/B | source | fitted to? |
|---|---|---|---|---|---|
| Gar Wood Speedster | 16 ft | 5.4 ft | 2.96 | [GW] | no |
| Chris-Craft 17 ft Runabout Deluxe, 1937 | 17.00 ft | 6.00 ft | 2.83 | [BD] | no |
| Chris-Craft 27 ft Custom Runabout | 27 ft | 7 ft 2 in | **3.77** | [S] | no |

The trend is monotonic in the right direction — a longer hull of the type is relatively
narrower — which is what makes the 27-footer's beam credible rather than merely printed.

**THE REJECTED ALTERNATIVE, WHICH THIS LANE VERY NEARLY SHIPPED.** Before [S] was found, the
beam was going to be an ESTIMATE for the **25 ft** Custom Runabout, reasoned from [BD]'s
17 ft × 6 ft at an L/B raised to 3.2–3.4 for the longer hull: **2.24–2.38 m**. The measured
answer for a hull two feet longer is **2.184 m**, so that reasoning was wrong in the right
direction and by about 10 per cent, and the ratio it assumed (3.3) was wrong by 14 per cent.
It is written down because it looked entirely reasonable and would have gone unchallenged.

**One published figure disagrees with another and both are recorded.** [BD] prints the 1937
17 ft Runabout Deluxe at a 6.00 ft beam; a Boat Trader listing for a 1938 17 ft Deluxe prints
**7.17 ft**. That is a 20 per cent disagreement inside one builder's one model, so neither is
used for anything and the L/B row above carries only the one that fits the trend. A single
source is a claim.

### What could not be found at all

No **weight or displacement** for any pre-war Chris-Craft runabout was readable in this
session. Every brokerage listing, the builder's own site and both museums with Chris-Craft
holdings print length and engine and nothing else. The model's mass is therefore an ESTIMATE
from the hull volume and the published double-planked mahogany construction, and it is tagged
as one where it is used. **What would settle it:** an original Chris-Craft catalogue page or
specification sheet — the Mariners' Museum holds the company's boat archive for 1922–1982 and
answers by e-mail, which is not something an agent can do.

**Sites that refused this session's fetch**, for the list in `modelling_here.md` section 2:
**hagerty.com returns HTTP 403** to an agent, and its marine articles carry specification
boxes that would have answered several of the questions above. `sailboatdata.com`, already on
that list, was not needed. Everything else below was readable.

---

## 2. The arrangement

| feature | what the sources say | tag |
|---|---|---|
| Cockpits | three separate seating areas, bench seats with kapok filling, "similar to the seats in a big touring car" | PUBLISHED [SO], [S] |
| The helm | **forward**: "the driver sat up front behind an adjustable windshield" | PUBLISHED [SO] |
| The engine | **between the middle and the aft cockpits** | PUBLISHED [SO] |
| Helm fittings | automobile-style banjo steering wheel, throttle controls, a dashboard with gauges, a floor-mounted gearshift | PUBLISHED [SO], [S] |
| Windscreen | single-pane tempered glass; the 25 ft carries dual windshields with adjustable side wings | PUBLISHED [S], [CB25] |
| Chrome deck hardware | cutwater, chocks, cleats, engine-compartment vents, navigation lights | PUBLISHED [S] |
| Cockpit soles | planked, covered with black rubber mats; forward and aft soles lift for bilge access | PUBLISHED [S] |

**THE ENGINE IS AFT OF THE MIDDLE COCKPIT, NOT FORWARD OF IT**, and this lane was briefed the
other way round. [SO] is explicit — *"The gas engine ... was mounted between the middle and aft
cockpits"* — and [S] is consistent with it. So the arrangement, bow to stern, is:

    stem — foredeck — HELM COCKPIT (windscreen) — MIDDLE COCKPIT — engine box — AFT COCKPIT — quarterdeck — transom

which also explains the shape of the boat in every photograph: the long unbroken run of deck is
**aft** of the two forward cockpits, not forward of them.

---

## 3. The colours, and how they were measured

**This is the part the brief said was most likely to go wrong, so none of it is remembered.**
`measure_photos.py` in this folder re-derives every figure below from the three photographs
alone. It reads nothing out of this file and nothing out of `runabout.gd`, so all three can
disagree and two of them be wrong.

### The rule that governs the whole section

**A photograph's pixel is albedo times light; a vertex colour is albedo alone.** No absolute
pixel value from any frame may be typed into the model. What crosses is a **ratio taken inside
one frame**, because the light divides out.

That single rule produced the section's most useful finding. **The deck reads markedly lighter
than the topsides in every one of the three photographs, and the model must not bake that in**,
because the deck is the same varnished mahogany and reads lighter only for facing the sky. Drawn
as a lighter colour it would be lighter *again* once the game lit it, and a mahogany deck would
come out tan. What actually distinguishes the deck is **the stained-walnut king plank and
covering board and the white seam compound between the planks** — not a lighter wood.

### What was measured

Eight mahogany patches, on two different boats, in two different lights (one flat overcast, two
in bright sun), at three stations each. Reported as the chromaticity — the colour normalised so
red is 1 — which is the illumination-independent quantity:

    G:R  0.185  sd 0.029  (16 per cent)
    B:R  0.095  sd 0.024  (26 per cent)

**The residual is printed rather than described.** A spread that size across two boats and two
lights is what says the hue belongs to varnished mahogany and not to one afternoon. The widest
patch is the sunlit forward topside, which picks up sky and reads bluer; the flattest two are
the overcast frame's.

**The LEVEL is a judgement and is said to be one.** Only the overcast frame [P2] is lit flatly
enough to stand for a paint chip, so its topside — sRGB (105, 44, 34), linear (0.141, 0.025,
0.016) — is what sets how bright the wood is. The two sunlit frames set the hue and are not
allowed to set the level.

### The palette

Every colour is **sRGB**, because every ship mesh here is drawn by `ShipHull.painted()`, which
sets `vertex_color_is_srgb`. Read as linear the same numbers come out near white.

| part | `Color(...)` | 8-bit sRGB | tag |
|---|---|---|---|
| Varnished mahogany, topsides and decks | `0.46, 0.20, 0.13` | 117, 51, 33 | hue MEASURED (8 patches, 3 photographs); level judged, then RAISED after looking -- see below |
| Stained walnut, king plank and covering board | `0.26, 0.16, 0.12` | 66, 41, 31 | ESTIMATE from the PUBLISHED material name [S]; no frame resolves one |
| Deck seam compound | `0.72, 0.69, 0.62` | 184, 176, 158 | ESTIMATE; a dirty cream, not a white |
| White painted stripe at the waterline | `0.90, 0.90, 0.88` | 230, 230, 224 | MEASURED [P1], where it clips the frame's white point |
| Bronze antifouling below it | `0.22, 0.13, 0.05` | 56, 33, 13 | ESTIMATE; [P1] reads it near black, wetted and shaded |
| Polished chrome | `0.74, 0.76, 0.78` | 189, 194, 199 | ESTIMATE |
| Cockpit glass | `0.32, 0.38, 0.44` | 82, 97, 112 | ESTIMATE |
| Black rubber cockpit mats | `0.09, 0.09, 0.10` | 23, 23, 26 | PUBLISHED material [S] |
| Tan vinyl bench upholstery | `0.55, 0.44, 0.29` | 140, 112, 74 | ESTIMATE from the PUBLISHED material name [S] -- **not measured; see below** |

**THE LEVEL WAS RAISED AFTER LOOKING AT IT, AND THAT IS A JUDGEMENT CHANGED, NOT A MEASUREMENT CHANGED.** The
overcast frame puts the wood at linear red 0.14, and the first model drew it at exactly that: `Color(0.40, 0.17,
0.11)`. On screen, under this game's sun and its sky ambient, she came out nearly black-brown -- the photograph's own
level already has that afternoon's light divided into it once, so using it as an albedo applies the light twice. The
level is now linear red 0.19, `Color(0.46, 0.20, 0.13)`, **at the same measured hue** -- the chromaticity the script
prints is untouched and still arbitrates the colour. What moved is the one number that was always a judgement, and it
moved because of CLAUDE.md rule 2 and a picture.

**TWO COLOURS WERE MOVED APART FOR A REASON THAT HAS NOTHING TO DO WITH THE BOAT.** `SurfaceTool.commit` quantises
vertex colour to eight bits a channel, and every suite in this workshop finds a part BY its colour. The first
draft's stained walnut (0.24, 0.13, 0.09) and bronze antifouling (0.26, 0.12, 0.08) were **two hundredths apart on
all three channels** -- eight steps of 255 -- so no check could ever have told a covering board from the bottom
paint. Walnut went cooler and the antifouling darker, and every pair in the table above is now at least 0.03 apart
in some channel.

**THE UPHOLSTERY WAS ATTEMPTED AS A MEASUREMENT AND THE ATTEMPT IS RECORDED AS A FAILURE.**
Three boxes on [P2]'s benches came back (49, 47, 62), (54, 31, 36) and (118, 113, 123) with
**standard deviations of 38 to 50 on every channel** — because the seats have people sitting in
them and the boxes caught shirts, arms and the far side of the boat. A reading whose spread is
as large as the reading is not a measurement, and it was very nearly written down as one.
[S] prints the material — "tan vinyl benches" — so the table carries a published name and an
estimated colour, which is the honest pair.

**Two of these are not what the brief expected, and the photographs are why.**

- **A white boot stripe is a VARIANT, not the type.** [P1]'s boat carries two painted white
  stripes, one at the sheer and one above the chine. [P2]'s carries **none at all** — she has a
  polished chrome rub rail where the other has paint. Both are Chris-Craft runabouts. The model
  draws the stripe because it reads at a distance and because it is what the brief asked for,
  and `sources.md` records that a boat without one is equally correct.
- **The topside plank seams read DARKER than the planking, not paler.** The pale seam is a DECK
  feature — white compound in the deck's caulked seams — and the hull's seam-and-batten topside
  seams are fine dark lines [P2], [P3]. Drawing pale seams down the topsides would be the deck's
  detail put on the wrong surface.

---

## 4. The references, and their licences

**None is incorporated into the game.** They were studied; no pixel, outline or texture from any
of them is in the repository or in the model. The three CC-licensed files were downloaded to
`~/godotgames-drafts/2026-09-20/chriscraft/research/` for study and are not redistributed.

| tag | what | licence |
|---|---|---|
| [P1] | Commons `File:Chris Craft Runabout 1945 runnin 02 LakeMirrorClassic 17Oct09 (14620607843).jpg`, Valder137, 1200×803 | **CC BY 2.0** |
| [P2] | Commons `File:Chris Craft Special Runabout 1941 runnin 01 LakeMirrorClassic 17Oct09 (14413898450).jpg`, Valder137, 1200×803 | **CC BY 2.0** |
| [P3] | Commons `File:Chris Craft Runabouts playin LakeMirrorClassic 17Oct09 (14620607993).jpg`, Valder137 | **CC BY 2.0** |
| [S] | Sierra Boat Company, 1934 Chris-Craft 27 ft Custom Runabout (Custom 309) — <https://sierraboat.com/product/sold-boats/1934-chris-craft-27ft-custom-runabout/> | all rights reserved; read, not copied |
| [SO] | Soundings, "Classics: Chris-Craft triple cockpit" — <http://soundingsonline.com/boats/classics-chris-craft-triple-cockpit/> | all rights reserved; read, not copied |
| [CB25] | classicboat.com, "Identify Your Chris Crafts 1933–1938 25' Custom Runabout", hull numbers 25000/25075 — <https://www.classicboat.com/id-25-ft-chris-craft-custom-runabout-triple-cockpit-1933-1938.htm> | all rights reserved; read, not copied |
| [BD] | boatsdata.com, 1937 Chris-Craft Runabout Deluxe — <https://www.boatsdata.com/1937-chris-craft-runabout-deluxe-60160/specs> | all rights reserved; read, not copied |
| [GW] | Wikipedia, *Gar Wood Speedster* — <https://en.wikipedia.org/wiki/Gar_Wood_Speedster> | CC BY-SA 4.0 text |

**No photograph of a genuine TRIPLE-cockpit boat was found under a free licence.** All three
CC-licensed frames are two-cockpit runabouts of the same builder and era, so they are used for
**colour, hull profile and finish only** — never for the cockpit stations, which come from the
published arrangement in section 2 instead. Saying which question each reference may be asked
is the whole of the discipline here: a measurement of the wrong object is worse than an honest
judgement of the right one.

**What would settle the open questions:** a free-licensed plan or overhead view of a triple
cockpit boat would fix the cockpit stations and the deck crown by measurement instead of by
arrangement; an original Chris-Craft specification page would fix the weight. Both are recorded
here as outstanding rather than invented.
