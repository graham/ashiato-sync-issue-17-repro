# High-speed catamaran ferry visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/ships/ferry.gd`). It contains no downloaded mesh, photograph, texture,
trademark or livery, and it carries no operator's colours or name: it is the ship type, with
one real vessel as its dimensional reference.

## The reference ship

**HSC Express 3**, IMO 9793064, a 109 m wave-piercing catamaran built by Incat at Hobart
(hull 088), launched and delivered April 2017, running for Molslinjen between Aarhus and
Sjællands Odde. [Wikipedia's article](https://en.wikipedia.org/wiki/HSC_Express_3) gives the
particulars used here. Chosen because it is a modern car-and-passenger catamaran in service
with a full set of published dimensions, and because Wikimedia Commons holds 25 freely
licensed photographs of it, including a near bow-on telephoto that shows both demihulls, the
centre bow and the tunnel at once.

PUBLISHED, and the visual scale contract:

| | |
|---|---|
| Length overall | 109.40 m |
| Length at the waterline | 102.30 m |
| Beam | 30.50 m |
| Draught | 3.93 m |
| Depth | 9.20 m, so the vehicle deck is 5.27 m over the water |
| Tonnage | 10,842 GT, 1,000 t deadweight |
| Machinery | 4 × MAN 20V 28/33D, 36,400 kW, driving 4 Wärtsilä WXJ 1500 waterjets |
| Speed | 40.0 knots in service, 47.0 maximum |
| Capacity | 1,000 passengers, 411 cars (or 227 cars and 610 lane metres), crew 22 |

Not published anywhere reached: the demihull's beam, the wet-deck clearance, the air draught
and the displacement.

## The photographs

| Id | File | Licence |
|---|---|---|
| F1 | `20170710 Molslinjen Aarhus 10 (36005662232).jpg`, Johan Wessman — nearly bow-on, telephoto | CC BY 2.0 |
| F2 | `Molslinjen HSC Express 3 (2018-06-22).jpg`, Johan Wessman — the bow quarter | CC BY 2.0 |
| F3 | Commons category `Express 3 (ship, 2017)`, 22 further photographs by HenSti | CC BY-SA 4.0 |

Study references: nothing from them is redistributed.

## What is MEASURED

On F1, which is a telephoto from 8.9 degrees off the bow — measured from the visible side
(440 px for 109.4 m) against the bow front (785 px for 30.5 m), so cos 0.988 and 26.0 px a
metre. Over the waterline:

| Feature | Height |
|---|---|
| Centre-bow forefoot | 1.5 m |
| Wet deck, the tunnel's roof aft | 3.5 m |
| Sheer, the hull side's top | 13.6 m |
| Passenger window band | 15.0 to 16.5 m |
| Roof | 17.5 m |
| Wheelhouse roof | 20.8 m |
| Masthead | 24.4 m |

Cross-check: the published 9.20 m depth puts the vehicle deck 5.27 m over the water, which is
the measured 3.5 m wet deck plus about 1.8 m of structure. Consistent, and the hull side above
it carries the freight deck with its car mezzanines up to the passenger deck at 13.6 m.

ESTIMATE: the demihull's beam, 5.10 m (Incat's published 4.33 m hull beam on a 26 m overall
beam for the 91.3 m Catalonia, scaled to 30.5 m), so the tunnel between the hulls is 20.3 m;
the demihulls' stems 2.7 m abaft the centre bow's nose, the centre bow running 24.7 m aft of
it; the superstructure's ends; the wheelhouse 38.7 m abaft the bow, 11 m by 8 m; the hull's
sections; the exhausts at the after corners and the liferaft stations on the roof.

Datum and axes: the origin is midships on the design waterline, forward is `-Z`, up is `+Y`,
starboard is `+X`, one Godot unit is one metre.

## The expected differences from the photographs

The model is low-poly and faceted on purpose, and these are deliberate, not errors:

- the sheer is straight; the real one sweeps up forward;
- the superstructure and the wheelhouse are square-cornered boxes, where the real ones are
  rounded and tapered forward;
- the tunnel's roof is flat, where the real wet deck is an arch;
- the demihulls are wall-sided above the water with a straight chine;
- there are no vehicle ramps, door openings, evacuation chutes or radar arrays.

## In the game

The kind is `ferry`. Its mass is 2,800 t: the full-load displacement is not published, so this
is the 1,000 t deadweight with a lightship estimated at 1,800 t — real scale, well under the
capital ships' cap. Its four buoyancy probes stand at 0.75 of the 15.25 m half-beam, which is
11.4 m out and inside each demihull, so the roll stiffness of the catamaran comes from where
its hulls are without a change to the simulation.
