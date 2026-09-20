# Crude carrier (VLCC) visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/ships/crude_carrier.gd`). It contains no downloaded mesh, photograph,
texture, trademark or livery, and it carries no operator's colours, funnel mark or name: it
is the ship type, with one real vessel as its dimensional reference.

## The reference ship

**MV Sirius Star**, IMO 9384198, a very large crude carrier built by Daewoo Shipbuilding &
Marine Engineering at Okpo (yard 5302), launched 28 March 2008.
[Wikipedia's article](https://en.wikipedia.org/wiki/MV_Sirius_Star) gives the particulars used
here. Chosen because it is a named modern VLCC with published dimensions and because the
United States Navy photographed it from the air in November 2008 and January 2009, which puts
a dozen **public-domain** photographs of one hull in the record.

PUBLISHED, and the visual scale contract:

| | |
|---|---|
| Length overall | 332 m (a second listing says 333 m, with 320 m between perpendiculars) |
| Beam | 60 m |
| Draught | 22.5 m |
| Depth, keel to deck | 31 m, so 8.5 m of freeboard laden |
| Deadweight | 318,000 t; 162,252 GT; 2.2 million barrels |
| Machinery | one propeller, diesel; crew 26 |

Not published anywhere reached: air draught, service speed, displacement, and where the
accommodation stands along the ship. Those are MEASURED below or marked ESTIMATE in the model.

## The photographs

All are on Wikimedia Commons and all are works of the US Navy, in the **public domain**. They
are study references: nothing from them is redistributed.

| Id | File |
|---|---|
| P1 | `Sirius Star 2008a.jpg` and `Sirius Star 2008d.jpg` (081119-N-0075S-001 / -004), broadside from the air |
| P2 | `US Navy 090109-N-5512H-148 The MV Sirius Star is observed at anchor by the U.S. Navy.jpg`, close on the house |
| P3 | `US Navy 090109-N-5512H-151 ...` and `-046`, the stern and the quarter |
| P4 | `US Navy 090109-N-5512H-032 he MV Sirius Star is observed at anchor.jpg`, from ahead and above |
| P5 | `MV Sirius Star 2009a.jpg`, from astern and above |

## The tanker's scale, and the two scales rejected

The house's heights were first taken off P2 as **ratios of the freeboard**: about 0.44
freeboards a deck, the navigation bridge deck at 2.20, the wheelhouse roof at 2.62 and the
masthead at 4.43. What a freeboard was worth in metres needed a second measurement, and three
candidates disagreed:

1. **The laden freeboard, 8.5 m** — depth 31 less draught 22.5, the ship being laden when
   photographed. Gives 3.7 m a deck.
2. **The deck rail at 1.0 m** (the Load Line minimum), read as 15 px on P2. Gives a 12.9 m
   freeboard, which is a draught of 18 m.
3. **A 3.0 m accommodation deck**, the usual figure for a merchant house. Gives a 6.8 m
   freeboard, which is a draught of 24.2 m — deeper than the ship's own scantling draught, so
   this one is impossible rather than merely unlikely.

**Settled on (1), confirmed independently on P4.** P4 looks at the ship from nearly dead
ahead, so a horizontal length across the ship is unforeshortened: the bridge wings span the
beam, 590 px for 60 m, giving 9.83 px a metre. The verticals are foreshortened by the
camera's depression, measured as 20.2 degrees from the ellipse of the painted winching circles
(minor over major 0.345), so cos 0.938. Read that way, over the cargo deck:

| | P4 | P2's ratio implies a freeboard of |
|---|---|---|
| Bridge wing walkway | 18.8 m | 8.53 m |
| Wheelhouse roof | 21.1 m | 8.07 m |
| Masthead | 37.7 m | 8.52 m |

A mean freeboard of 8.4 m against the published 8.5 m. Scale (2) is rejected on that: the rail
was misread. Scale (3) is rejected by the ship's own draught.

Cross-check: with the bridge deck 18.7 m over the cargo deck, a seated eye is 28.4 m over the
water and 255 m abaft the stem, so the sea is hidden for 383 m ahead — inside SOLAS V/22's
500 m.

## What is MEASURED, and what is an ESTIMATE

MEASURED:

- the house front 77 m forward of the stern (75.4 m on `2008d` and 78.7 m on `2008a`, by a 1-D
  cross ratio along the deck with the stern and stem as the ends and the manifold cranes taken
  to be at mid-length — that assumption is what carries it, so it is low confidence);
- over the cargo deck: bridge deck 18.7 m, wheelhouse roof 22.3 m, funnel top 30.2 m,
  masthead 37.7 m; five decks and a wheelhouse, 3.7 m a deck;
- the lower tiers 36.4 m across and the wheelhouse 15.3 m (P4), the bridge wings out to the
  ship's side;
- the deck round and abaft the house 2.6 m below the cargo deck (P2, P3: the hull's top edge
  steps down 60 px against a 193 px freeboard);
- the foremast at the stem head (P4), not amidships;
- the funnel a separate casing abaft the wheelhouse, and a free-fall lifeboat over the stern on
  the centreline (P5).

ESTIMATE: the fore-and-aft lengths of the house's tiers and of the funnel (no photograph looks
at them square); the bow's shoulder 55 m abaft the stem and a 44 m transom; the hull's sections
(a VLCC's block coefficient is about 0.8, so the side is vertical to three quarters of the
draught); the bulb, rudder and screw; the manifold amidships with a hose crane each side; the
pipe run, catwalk, mooring winches and winching circles.

Datum and axes: the origin is midships on the design waterline, forward is `-Z`, up is `+Y`,
starboard is `+X`, one Godot unit is one metre. The simulation's parts stay authoritative for
size, collision and seats; the model draws them.

## In the game

The kind is `crude_carrier`. Its mass is 10,000 t, the capital-ship figure the aircraft carrier
carries, rather than the real ship's roughly 360,000 t laden: the handling is tuned to it, and
a body a hundred thousand times a one-tonne aeroplane is a mass ratio the solver should not be
handed. The draught is where the keel is drawn, not what the mass is.
