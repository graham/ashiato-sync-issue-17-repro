# DHC-515 Firefighter visual reference

The runtime exterior is an original procedural model made from Godot primitives. It
contains no downloaded mesh, photograph, texture, trademark, or operator livery.

## Which aeroplane this is, which is not a detail

**The model is a DHC-515, and the craft kind is called `tanker`.** Those are two different
things and the file has to say which one is authoritative, because **the CL-215, the CL-415
and the DHC-515 are three different aeroplanes** — a piston amphibian, its turboprop
conversion, and De Havilland's current production development of the second. `modelling_here.md`:
*scale a drawing by the variant it depicts.* Every figure below is off the third one's sheet, so
the model is the third one. A reader who takes the craft's name as the answer will scale a
CL-415 drawing against DHC-515 numbers and be wrong by whatever the two differ by.

**The kind is not renamed and should not be.** `Sim.Kind.TANKER` is on the wire, in twenty-five
craft packages, in `craft/tanker/`, and in every saved cockpit layout. A rename is a wire change
for a caption. The name of the folder is an identifier; this file is the claim.

## The published figures, and what carries each one

De Havilland Canada's official [DHC-515 specification](https://dehavilland.com/wp-content/uploads/2025/01/DHC-515_Spec_Sheet_v14_DIGITAL.pdf)
gives a **19.8 m length, 9.02 m height, 28.6 m wingspan, 3.97 m propeller diameter**, and a
**6,137 litre** water capacity. `tests/aircraft_fidelity.gd` holds the drawn model to the first
three within two per cent; the fourth is drawn by `VehicleView.PROPELLER_DIAMETER`.

**A dimension has to be carried by the thing it names.** That sentence is here because on
2026-09-17 this aeroplane's 9.02 m height was being satisfied by a fin floating 1.79 m above the
tailcone, attached to nothing — the number was right and the aeroplane was in eighteen pieces.
The height is now the top of the tailplane, which is bolted to the fin tip, which is bedded into
the tailcone. See `_build_water_bomber_airframe`, and `tests/aircraft_fidelity.gd`'s
`_every_drawn_part_is_joined_to_the_aeroplane`, which was written for it.

The amphibious hull and keel, high wing, two turboprops, wingtip floats on struts, and the
T-tail are the defining exterior cues.

## What is measured and what is still by eye

**The overall envelope is measured; the fuselage loft is not.** The span, length, height and
propeller diameter come from the sheet above. The hull's section stations — how wide and how
deep the fuselage is at each point along it — were written by eye and have never been held
against a drawing. They are honest about being a flying boat and they are not a DHC-515's
actual sections. **A re-loft wants a three-view scaled by a stated caption**, per
`modelling_here.md`, and that drawing is not in the repository.

Those stations are also what `VehicleView._water_bomber_cabin_room` computes the crew's room
from, so anything measured against a drawing later moves both the skin and the promise together.

**A re-loft was attempted on 2026-09-17 and abandoned on the evidence.** Sixty-nine Commons files
in `Category:Canadair CL-415` were screened and every one is three-quarter, banked, obstructed or
hazed; **Commons holds no line drawing, silhouette or three-view of the type in any format**. The
search, the licence table, every rejection with its reason, and the script that re-derives it all
are in `cockpit/research/cl415_reference_search.md`. The closest candidate is about twenty degrees
off square, and at that angle the 28.6 m wing projects about 9.8 m across the view — comparable
with the 19.8 m hull — so the outline that looks like a side view is a hull and a wing
superimposed, and every station measured off it would carry that error silently. **Leaving these
sections by eye and saying so is the smaller lie.**

**And the user has ruled on the one source that would settle it (2026-09-17): De Havilland's spec
sheet is NOT to be fetched.** Its three-view is a manufacturer's copyrighted drawing, and tracing it
into the game's geometry is a licensing question worth avoiding. The span, length, height and
propeller diameter are already De Havilland's published figures and are held within two per cent;
only the hull's section stations are estimated, and they stay estimated and labelled. **The goal is
that it looks right and flies well**, in the user's words -- *"exact specs are less important to me"*
-- so nobody should spend time sourcing a more exact hull than this.

## Where the sea stands on it, which is derived and not measured

The water bomber floats (`tanker_shape`'s `amphibian`, 2026-09-17) with the sea at **h -1.09 in its
own frame**. **Nobody has measured that.** No photograph of a CL-415 at rest on the water exists in
the 69 files of Commons' category; every one on the water is mid-scoop in spray.

So it is derived from the only two things this model promises about the hull. The crew's floor is
the seat poses' y, **-0.50, and must be dry**. The hull's lowest drawn point is **-1.68, and must be
wet**. Midway is -1.09: 0.59 m of freeboard and 0.59 m of draught. `tests/water.gd` does not check
-1.09. **It checks the bracket, off the physics after it settles**, because the bracket is what can
be wrong.

**What would retire it:** a photograph of a 415 at rest on the water, measured as *waterline height
over hull depth* at a station. That is a pure ratio, so it needs no scale and survives a photograph
nobody can scale (`lane/cooling`'s technique, `cockpit/research/`). The default this replaced was
wrong in a way that looked right: it floated the hull 2.33 m deep, with the crew underwater.

The hull's drag on the water is every `Handling`'s boat default, the same keel a ship uses, applied
fore-and-aft as well as across and scaled by how wet the hull is. **It is unmeasured too**, and the
suite PRINTS the run-out a landing gets from it rather than claiming one.

## Datum and axes

The craft origin is the centre of the published aircraft envelope, forward is `-Z`, up is `+Y`,
and one Godot unit is one metre. The native water system, collision, flight model, and four
existing station identifiers remain authoritative.

## The water system, and the one decision that is the user's

The tank fills **only on a scooping run** — low over open water, inside the 25 to 62 m/s band
`is_scooping` requires. **Landing on the water and sitting there fills nothing.** That is the
user's ruling of 2026-09-17, and the reason is balance rather than physics: it preserves the
round-trip economy `FireFront.SPREAD_SECONDS` (30 s) was tuned against, **and it keeps the skill
in the manoeuvre** — line up, descend, hold a speed band over water, which is the interesting
part of flying a water bomber.

Two alternatives were put and turned down: filling while parked, because it removes the scoop
run as a skill and makes the round trip faster than the fire spread was tuned against; and a
slower parked fill, because that is the same problem with a fudge factor in front of it. **Both
rejected options were the ones that would have needed a new number nobody had measured.**
