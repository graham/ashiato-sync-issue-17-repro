// HOW MUCH OF THE SEA'S MOTION A WATER SURFACE GETS, AND THE ONE PLACE THAT DECIDES (lane/rivers, 2026-09-20).
//
// The seas move their vertices by the simulation's standing swell, the wind-sea the boats feel and -- on the fine
// finish -- four Gerstner waves of chop. None of that belongs on a lake or a river. Until this file, the only thing
// stopping it was a GEOMETRIC ACCIDENT: each shader worked out `max(|x|, |z|) - land_half` for itself and faded the
// motion in from 40 m to 260 m past it, and `land_half` was handed `Terrain.WORLD_HALF`, 7,200 m -- the ISLAND level's
// half-width -- whatever level was being flown.
//
// WHAT THAT COST, measured by `tests/rivers_survey.gd` on 2026-09-20: the generated levels put their lakes wherever
// the hash puts them, out to 19 km, and THIRTY OF THE FIFTY-FOUR stood outside that band at a motion factor of 1.00 of
// full. Alpine's westernmost lake is 27 m above the sea and 15.3 km out, and it heaved with the open sea's swell while
// `Terrain.water_height` -- what a hull actually floats on, and what `LakeSheets` lays its vertices at -- stayed flat.
// Both `lake_sheets.gd` and `sea_surface.gdshaderinc` carried a doc block claiming a lake is "inside the coast band,
// where both ocean shaders move nothing", which was true on the island and false on every generated level.
//
// SO INLAND WATER SAYS SO, rather than being inferred from a radius (RULES 5: announce, don't act). `WaterSurface.wear`
// takes it, `LakeSheets` passes it, and a lake is still wherever in the world it happens to lie. It is not enough to
// withhold the swell: `ocean_fine.gdshader`'s `swell_steepness` defaults to 0.15 in the shader itself, so a lake on
// FINE chopped even with nothing handed to it.
//
// AND THE GATE IS IN ONE PLACE NOW (RULES 4). `ocean.gdshader`, `ocean_fine.gdshader` and `sea_surface.gdshaderinc`
// each typed the same two lines, and a wake had to agree with the sea it lies on to the centimetre. They include this.
#ifndef STILL_WATER_GDSHADERINC
#define STILL_WATER_GDSHADERINC

// Half the island's width, metres: the sea is only given a shape outside it. The generated grounds have a wandering
// circular coast that this square cannot describe, which is why inland water is told rather than measured.
uniform float land_half = 7200.0;
// 1.0 for water that is not the sea -- a lake, a river, a pond -- which gets none of the sea's motion at any distance.
uniform float inland = 0.0;

// THE SHARE OF THE SEA'S MOTION at a point in world metres: nothing on inland water, nothing on or near the land, and
// all of it out at sea.
float sea_motion(vec2 xz) {
	float offshore = max(abs(xz.x), abs(xz.y)) - land_half;
	return (1.0 - inland) * smoothstep(40.0, 260.0, offshore);
}
#endif
