extends RefCounted
class_name Ammunition
## WHAT A ROUND LOOKS LIKE, WHICH IS NOT WHAT IT DOES.
##
## The simulation's table -- `gun_schema` -- says how a round FLIES: its drag and how long
## it lasts. This one says how it LOOKS: the tracer on the way out and the mess at the other
## end. They are deliberately two tables, because they answer to two different things. A
## drag coefficient has to agree with every machine in the session; a fireball has to agree
## with nobody, and a client drawing a slightly bigger one is not a client that is wrong.
##
## THE ROWS ARE NOT ONE EXPLOSION SCALED BY A NUMBER, and that is the whole point of having
## a table at all. A sabot round has NO fireball -- it is a tungsten dart, there is nothing
## in it to go off, and what you get is a spray of sparks and a dust plume. Canister has no
## fireball either and a wall of dust instead. If the four rounds looked like four sizes of
## the same orange ball there would be no reason to choose between them.

## Indexed by the ammunition number the simulation puts on the wire. `name` is checked
## against the simulation's own name for the same index -- see the test -- because two
## tables keyed by the same number are two tables that can drift apart.
const LOOK: Dictionary = {
	0: {
		"name": "sabot",
		# A dart, and it is mostly a streak: 1700 m/s is twenty-eight metres in a frame.
		"tracer": Color(0.98, 0.88, 0.62), "streak": 34.0, "calibre": 0.10,
		"fireball": 0.0, "fire_colour": Color(1.0, 0.85, 0.45),
		"flash": 3.2, "flash_colour": Color(0.95, 0.96, 1.00),
		"dust": 9.0, "smoke": 0.0, "sparks": 22, "spark_speed": 34.0, "seconds": 1.1,
	},
	1: {
		"name": "heat",
		"tracer": Color(0.95, 0.72, 0.35), "streak": 16.0, "calibre": 0.14,
		# A shaped charge is a small, hard, white event. It is not a big bang; it is a jet
		# of metal going one way very fast indeed.
		"fireball": 3.4, "fire_colour": Color(1.00, 0.92, 0.72),
		"flash": 5.0, "flash_colour": Color(1.00, 0.98, 0.90),
		"dust": 7.0, "smoke": 5.0, "sparks": 14, "spark_speed": 22.0, "seconds": 1.6,
	},
	2: {
		"name": "he",
		# HEAVY: it lands as a big explosion sized from its calibre (`BurstTuning`), not as the
		# `Burst` below. The rows keep their old "fireball" as the record of what it drew before,
		# which is what the three-times rule is measured against.
		"heavy": true,
		"tracer": Color(0.92, 0.55, 0.25), "streak": 12.0, "calibre": 0.16,
		# The one that looks like an explosion looks in everybody's head.
		"fireball": 7.5, "fire_colour": Color(1.00, 0.62, 0.18),
		"flash": 4.0, "flash_colour": Color(1.00, 0.90, 0.60),
		"dust": 16.0, "smoke": 12.0, "sparks": 18, "spark_speed": 26.0, "seconds": 2.6,
	},
	3: {
		"name": "canister",
		# A cloud of tungsten balls. Short, fat, and gone by five hundred metres.
		"tracer": Color(0.85, 0.80, 0.70), "streak": 7.0, "calibre": 0.30,
		"fireball": 0.0, "fire_colour": Color(1.0, 0.9, 0.6),
		"flash": 1.6, "flash_colour": Color(0.98, 0.95, 0.85),
		"dust": 13.0, "smoke": 0.0, "sparks": 40, "spark_speed": 18.0, "seconds": 1.2,
	},
	4: {
		"name": "25mm",
		# A stream rather than a series of bangs: thirty a second, and what you see from
		# the ground is a line of light that stays put while the aeroplane moves.
		"tracer": Color(1.00, 0.72, 0.30), "streak": 9.0, "calibre": 0.06,
		"fireball": 1.4, "fire_colour": Color(1.00, 0.78, 0.35),
		"flash": 1.8, "flash_colour": Color(1.00, 0.95, 0.80),
		"dust": 4.0, "smoke": 2.0, "sparks": 8, "spark_speed": 14.0, "seconds": 0.9,
	},
	5: {
		"name": "40mm",
		"heavy": true,
		"tracer": Color(0.98, 0.62, 0.28), "streak": 11.0, "calibre": 0.10,
		"fireball": 3.6, "fire_colour": Color(1.00, 0.66, 0.24),
		"flash": 2.6, "flash_colour": Color(1.00, 0.92, 0.72),
		"dust": 8.0, "smoke": 6.0, "sparks": 14, "spark_speed": 20.0, "seconds": 1.7,
	},
	6: {
		"name": "105mm",
		"heavy": true,
		# Fifteen kilograms of artillery shell, arriving slowly and taking its time about
		# what happens next. The biggest thing in the table by some way.
		"tracer": Color(0.88, 0.52, 0.22), "streak": 8.0, "calibre": 0.24,
		"fireball": 11.0, "fire_colour": Color(1.00, 0.56, 0.14),
		"flash": 5.5, "flash_colour": Color(1.00, 0.88, 0.55),
		"dust": 24.0, "smoke": 20.0, "sparks": 24, "spark_speed": 30.0, "seconds": 3.4,
	},
	8: {
		"name": "water",
		# HALF A TONNE OF WATER, and everything about this row is the opposite of the rows
		# above it. It does not glow, so the tracer colour is what it is lit by rather than
		# what it emits -- see ShotYard, which draws this one in plain alpha where a round
		# is additive. It does not explode. What it does at the far end is throw a white
		# sheet up off the ground and leave a dark wet patch, and that is the only mark in
		# this table anybody is pleased to see.
		"tracer": Color(0.72, 0.86, 0.95), "streak": 2.6, "calibre": 1.30,
		"wet": true,
		"fireball": 0.0, "fire_colour": Color(0.8, 0.9, 1.0),
		"flash": 0.0, "flash_colour": Color(1.0, 1.0, 1.0),
		"dust": 9.0, "smoke": 0.0, "sparks": 14, "spark_speed": 11.0, "seconds": 1.4,
		# The spray is WHITE, whatever it landed on. Every other round takes its colour
		# from the surface -- a shell throws up whatever it hit -- and water throws up
		# water.
		"dust_colour": Color(0.86, 0.92, 0.96),
	},
	7: {
		"name": "7.62mm",
		# A BULLET, and the only thing in this table that is not artillery of some kind.
		# There is nothing in it to go off: what you see at the far end is a puff of dirt
		# and a couple of sparks, and what you see on the way there is a THIN line of
		# light. Every fifth round is a tracer on a real belt, which is why one gun firing
		# eleven a second reads as a rope rather than as eleven separate things.
		"tracer": Color(1.00, 0.60, 0.30), "streak": 6.0, "calibre": 0.025,
		"fireball": 0.0, "fire_colour": Color(1.0, 0.8, 0.4),
		"flash": 0.55, "flash_colour": Color(1.00, 0.94, 0.80),
		"dust": 1.3, "smoke": 0.0, "sparks": 4, "spark_speed": 9.0, "seconds": 0.5,
	},
	9: {
		"name": "12.7mm",
		# A HEAVY MACHINE GUN's, off a ship's rail: still a bullet, still nothing in it to go
		# off, and a little more of everything than a door gun's -- a thicker, redder line and
		# a bigger puff of whatever it hit. Still a puff: at nine rounds a second a fireball
		# each would be a wall.
		"tracer": Color(1.00, 0.55, 0.28), "streak": 7.0, "calibre": 0.035,
		"fireball": 0.0, "fire_colour": Color(1.0, 0.8, 0.4),
		"flash": 0.8, "flash_colour": Color(1.00, 0.94, 0.80),
		"dust": 2.0, "smoke": 0.0, "sparks": 6, "spark_speed": 11.0, "seconds": 0.6,
	},
	10: {
		"name": "406mm",
		# A BATTLESHIP'S SHELL (plan item 22): a tonne of it, fifteen seconds in the air, and "big explosion no fire" at
		# the far end. HEAVY, so it lands as a `HeavyBurst` sized from its 406 mm bore (`BurstTuning`) -- the biggest in
		# the game by nearly four times, which is the point: the splash is the fall of shot a gunner six kilometres away
		# corrects by, and a burst they cannot see from there is a gun they cannot aim. "fireball" is 0 because it has
		# no old ball to be measured against, and a size here would move every other heavy round's rule.
		"heavy": true,
		"tracer": Color(0.98, 0.70, 0.38), "streak": 14.0, "calibre": 0.50,
		"fireball": 0.0, "fire_colour": Color(1.00, 0.56, 0.14),
		"flash": 9.0, "flash_colour": Color(1.00, 0.88, 0.55),
		"dust": 40.0, "smoke": 30.0, "sparks": 30, "spark_speed": 40.0, "seconds": 4.5,
	},
	11: {
		"name": "30mm",
		# THE A-10's GAU-8: the 25 mm's stream at 65 a second, a little brighter and a little fatter, and an armour-piercing
		# round's strike -- more sparks and dust, a small flash from the incendiary, no fireball worth the name.
		"tracer": Color(1.00, 0.78, 0.36), "streak": 10.0, "calibre": 0.07,
		"fireball": 0.8, "fire_colour": Color(1.00, 0.80, 0.40),
		"flash": 2.2, "flash_colour": Color(1.00, 0.96, 0.82),
		"dust": 6.0, "smoke": 2.5, "sparks": 16, "spark_speed": 18.0, "seconds": 1.0,
	},
}

## What a surface does to it, on top of the round's own table. Same shell, three messes:
## the impact record says what was hit -- see kSurface* -- and dirt throws a ring, water
## throws a column and armour throws sparks and almost no dust at all.
const SURFACE: Dictionary = {
	1: {"name": "ground", "dust": 1.0, "smoke": 1.0, "sparks": 1.0,
		"dust_colour": Color(0.62, 0.55, 0.42)},
	2: {"name": "water", "dust": 1.5, "smoke": 0.3, "sparks": 0.2,
		"dust_colour": Color(0.78, 0.84, 0.86)},
	3: {"name": "armour", "dust": 0.25, "smoke": 0.8, "sparks": 2.5,
		"dust_colour": Color(0.55, 0.55, 0.58)},
}

## Still in the air; nothing to draw at the far end yet.
const FLYING: int = 0
const GROUND: int = 1
const WATER: int = 2
const ARMOUR: int = 3
## Ran out of life without hitting anything. A round that expires in the air does NOT
## explode -- it is a shell that landed nowhere, and inventing a burst for it would put
## fireballs in the sky every time somebody fired at nothing.
const SPENT: int = 4


static func look(ammo: int) -> Dictionary:
	return LOOK.get(ammo, LOOK[2])


static func surface(what: int) -> Dictionary:
	return SURFACE.get(what, SURFACE[1])


## IS THIS ONE WATER? Asked rather than compared against a number, because "ammunition 8"
## at a call site is a number nobody can read -- and what the renderer wants to know is not
## which round it is but whether it GLOWS, which is the same question upside down.
static func is_wet(ammo: int) -> bool:
	return bool(look(ammo).get("wet", false))


## Does hitting this make anything at all?
static func explodes(what: int) -> bool:
	return what != FLYING and what != SPENT
