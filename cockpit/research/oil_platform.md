# The oil platform: which type, the references, and every measurement

`lane/oilrig`, 2026-09-18. The user asked: *"Hey i want an oil platform: https://en.wikipedia.org/wiki/Oil_platform
that can sit in the water. Model it like you did with the f16 and air craft carrier. Make it realistic."* The model is
`world/oil_platform.gd` (`OilPlatform`), placed by `world/oil_field.gd` (`OilField`), held by `tests/oil_platform.gd`
and photographed by `tests/oil_platform_shot.gd`.

**The runtime platform is an original procedural model. No downloaded mesh, photograph, texture, trademark or livery is
in it.** The photographs below were studied for proportion and features only, and they are kept outside the repository,
in `~/godotgames-drafts/2026-09-18/cockpit-oilrig/research/`.

## Which type, and why

The Wikipedia article lists fixed platforms (steel jacket, concrete gravity base), compliant towers, semi-submersibles,
jack-ups, drillships, tension-leg platforms and spars. **This is a fixed steel-jacket production platform**, for three
reasons:

1. **It is the one people picture.** It has the lattice legs, the stacked decks, the derrick, the flare boom and the
   helideck, as Montrose, Ula, Valhall and Thistle all do.
2. **It sits in the water by what it is.** It stands on the sea floor and rises through the surface. A semi-submersible
   floats, moors and heaves. Drawn standing still it would be a fixed platform pretending, and a floating one wants a
   buoyancy model that the game does not give scenery.
3. **The game's sea is the right depth for one.** Both worlds' open sea is about 150 m deep (`Seabed.depth`). The article
   puts fixed platforms "up to about 520 m". Thistle stands in 162 m, and Ula and Valhall in 70 m.

## Sources, and their licences

| Reference | Licence | Author | Used for |
|---|---|---|---|
| Wikipedia, *Oil platform* (text, via the API) | CC BY-SA 4.0 | Wikipedia contributors | the types; fixed platforms to 520 m |
| Wikipedia, *Thistle oil field* | CC BY-SA 4.0 | Wikipedia contributors | jacket "183 meters tall with a base measuring 85 meters by 82 meters", four main legs, 3 deck levels, living quarters and helideck at one end |
| Wikipedia, *Montrose oil field* | CC BY-SA 4.0 | Wikipedia contributors | the "horizontal 455 feet (139 m) long flare bridge" that scales the Montrose photograph |
| Wikipedia, *Ula oil field*, *Valhall oil field* | CC BY-SA 4.0 | Wikipedia contributors | 70 m of water |
| [File:Montrose Alpha.JPG](https://commons.wikimedia.org/wiki/File:Montrose_Alpha.JPG) | CC0 | Lee181169 | the broadside every height is measured off |
| [File:Ula Platform.jpg](https://commons.wikimedia.org/wiki/File:Ula_Platform.jpg) | CC BY 2.0 | tom jervis | jackets, derrick, lattice flare tower, cranes, lifeboats |
| [File:Valhall A oljeplatform.jpg](https://commons.wikimedia.org/wiki/File:Valhall_A_oljeplatform.jpg) | CC BY 4.0 | Knudsens Fotosenter | a white accommodation block of window rows under a cantilevered helideck |
| [File:Eko 2-4R jacket on H-627.JPG](https://commons.wikimedia.org/wiki/File:Eko_2-4R_jacket_on_H-627.JPG) | CC BY-SA 3.0 | BoH | a jacket out of the water: bays, X-bracing, batter |
| [File:Jacket of oil platform at Shipyard Chiwan.jpg](https://commons.wikimedia.org/wiki/File:Jacket_of_oil_platform_at_Shipyard_Chiwan.jpg) | CC BY-SA 3.0 | SteKrueBe | the same, a smaller jacket |
| [File:Oseberg feltsenter - AS 332 Super Puma.jpg](https://commons.wikimedia.org/wiki/File:Oseberg_feltsenter_-_AS_332_Super_Puma.jpg) | CC BY-SA 2.0 | Norsk olje og gass | helideck markings: the yellow touchdown circle and the perimeter |
| [File:Oil platform in the North Sea.jpg](https://commons.wikimedia.org/wiki/File:Oil_platform_in_the_North_Sea.jpg) | CC BY-SA 3.0 | Erik Christensen | a semi-submersible, for comparison with what this is not |
| [File:Types of offshore oil and gas structures.jpg](https://commons.wikimedia.org/wiki/File:Types_of_offshore_oil_and_gas_structures.jpg) | public domain | NOAA | the types, side by side |

## Measuring the Montrose broadside

Tags as in `modelling_here.md` section 3: **[W]** published on Wikipedia, **[M]** measured here, **[E]** estimate.

The photograph is 1920 x 1280 as fetched (Commons thumbnail of a 3072 x 2048 original). Rows and columns below are in
that 1920-wide frame.

**The water line is not one row.** Legs meet the sea at y = 992 under the platform and y = 1003 under the flare tripod,
with the horizon at y = 935, so **the tripod is 1.19 times nearer the camera than the platform**. A distance goes as
1 / (water row - horizon row): (1003 - 935) / (992 - 935) = 68 / 57 = 1.19. So the flare bridge runs towards the camera,
and a scale taken along it belongs to neither end (`modelling_here.md`: "a scale belongs to the station it was measured at").

**The scale, two ways that never saw each other:**

- **[W] the flare bridge, 139 m**, from the flare stack (x = 307) to the platform's edge (x = 1262), which is 955 px, gives
  **6.9 px a metre**. It is uncertain by up to the 1.19 above, because the bridge runs away from the camera.
- **[E] a North Sea air gap**: a cellar deck's underside about 22 m over the sea is usual. At the platform's station the
  underside is 152 px up (y = 840 against 992), which gives **6.9 px a metre**.

The two agree. Neither is good to better than a metre or so at the platform's station, and every figure below is only as
good as that.

| Feature | Pick (px, 1920 frame) | Above the water, px | Metres at 6.9 px/m | Used as |
|---|---|---|---|---|
| jacket top frame | y = 925 | 67 | 9.7 | `JACKET_TOP` 10.0 |
| cellar deck underside | y = 840 | 152 | 22.0 | `CELLAR_DECK` 22.0 (plate top; girders under it) |
| module roofs | y = 640 | 352 | 51 | the weather deck's modules to 48.5 |
| helideck | y = 567 | 425 | 61.6 | `HELIDECK_TOP` 61.0 |
| jacket top, across the outer legs | x = 1367 to 1740 | 373 wide | 54 | `LEG_X` +-27 |
| topsides overall, cantilevers to crane rest | x = 1250 to 1832 | 582 wide | 84 | decks 68 m, plus the quarters and helideck struts |
| leg diameter | about 15 px | | 2.2 | `LEG_DIAMETER` 2.4 |

**Not measured, and why.** The Montrose "derrick" (x = 1375 to 1412) is a clad tower 5 m across. Whether it is a derrick
or a vent stack cannot be settled at this resolution, so the derrick's height is **[E] 40 m over its drill floor**, taken
from the brief's 40–60 m range. **A feature you cannot identify cannot be measured**, however good the scale is.

## Cross-checks

- **[W] Thistle's base.** At Thistle's depth of 162 m, the model's batter (1 in 10 along, 1 in 7.5 across) puts the legs
  87.1 x 80.9 m apart at the floor, against a published 85 x 82 m. That is +2.5 and -1.3 per cent, held by
  `tests/oil_platform.gd:at_thistles_depth_the_base_is_thistles`.
- **The helideck.** The deck is 24 m across its flats. The largest helicopter in the game that would fly a crew out is
  the UH-60, at 19.76 m overall **[W]**, and an offshore deck is at least one D-value (the helicopter's overall length)
  across. A UH-60 dropped on it in a bare simulation rests 1.42 m over the deck, which is exactly the height it rests
  over the island's slab.

## What would improve this

- **A plan view of a real jacket's top frame.** The spacing across (36 m) is set so the base meets Thistle's. No
  reference here shows it.
- **A close broadside of a derrick** at a resolution where it can be told from a clad stack.
- **Helideck markings from the regulator** (CAP 437) rather than from a photograph. The H's orientation follows the
  heliport rule of the cross-arm square to the approach, from memory, and it is marked [E] in the model.
