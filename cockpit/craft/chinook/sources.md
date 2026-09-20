# CH-47F Chinook visual reference

The runtime exterior is an original procedural model made from Godot primitives. It
contains no downloaded mesh, photograph, texture, trademark, or operator livery.

Boeing's official [CH-47F Block II specification](https://www.boeing.com/defense/military-rotorcraft/h-47-chinook)
gives a 15.6 m fuselage length, 18.3 m rotor diameter, 30.1 m operating length, 5.7 m
overall height, and 3.8 m fuselage width. The long cargo fuselage, counter-rotating
tandem three-blade rotors, raised rear pylon, side fuel sponsons, wheeled gear, and rear
loading ramp are the defining cues.

Datum and axes: the craft origin is the centre of the fuselage envelope, forward is
`-Z`, up is `+Y`, and one Godot unit is one metre. The rear-facing ramp station is a
stable game station. Native collision, handling, networking, and all station poses
remain authoritative.


## The drawn airframe, 2026-09-17

`ChinookAirframe` (`objects/vehicles/chinook_airframe.gd`, on `RotorcraftKit`) replaced the
lofted oval with plank rotors on posts, whose rear rotor stood on empty air because it had
no aft pylon. It draws the forward pylon, the tall aft pylon and the drive-shaft tunnel
between them, three-blade counter-rotating rotors that mesh, engines on stubs beside the
aft pylon, the sponsons, four wheels, a row of cabin windows, and the ramp. The ramp is
hinged at the tail and follows the bus's "ramp" bit: level for the ramp gunner when down,
square across the tail when up. Wikipedia's "Boeing CH-47 Chinook" infobox gave the
proportions of the 0.81 m blade chord and the 2.29 x 1.98 m cabin. The fuselage runs
16.4 m, half a metre past the native box, so that the ramp gunner and his gun are under the
roof. The 18.3 x 5.7 x 30.1 m envelope holds, with each rotor measured by the disc it sweeps.
