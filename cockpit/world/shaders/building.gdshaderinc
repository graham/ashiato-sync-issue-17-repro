// A BUILDING: a box with a wall colour, a roof, and a grid of windows that keeps its size.
//
// ONE INSTANCE OF A UNIT BOX PER BUILDING, scaled in the basis -- see TownView. So the window grid
// cannot come from the mesh's UVs, which run 0..1 across every face whatever its size and would give
// a two-storey shop and a sixty-storey tower the same number of windows. It comes from FACADE
// COORDINATES instead: the box's own position scaled back up by the instance's size, which is
// metres along the wall and metres up it, cut into storeys and bays with floor and fract. A tower is
// then more windows, not bigger ones.
//
// NO TEXTURE, NO SCREEN OR DEPTH TEXTURE, NO FRAGCOORD, like every surface here. Metres from the box
// centre never exceed a few hundred, so none of this needs the world-position wrap the terrain does.
//
// WHICH WINDOW IS LIT MUST BE THE SAME ON EVERY PIXEL OF IT, which is why `face` and `shade_hash` are FLAT varyings:
// see the note on them. That was most of the flicker the user saw at night ("at evening and night, the windows on the
// buildings flicker a ton", 2026-09-13). Windows are not geometry and never fought the wall; there is nothing to move
// off it.
//
// AND A WINDOW TOO SMALL TO DRAW IS NOT DRAWN AS ONE, because a hard edge a pixel or two across turns on and off as the
// head moves. Every edge is ramped over one pixel (fwidth of the facade coordinate), and then:
//   PANES fade to what they average to once a window's smaller side is under `window_pixels_least` pixels -- by day a
//   pane is a little darker than its wall, and a facade of them averages to a tone;
//   LIGHTS do not average, because a field of lit windows averaged is a glowing slab: the first try drew the town from
//   900 m at night as amber blocks, the far town's orange blocks again. So the lit pattern is drawn on a COARSER GRID
//   instead -- two windows by two, then four by four -- with the same share of cells lit and each light the same share
//   of its cell, so the light a facade gives is kept and arrives as fewer points each big enough to draw. Neighbouring
//   grids cross-fade by the pixel size, so no light pops.
// A pixel is a size on the screen and not a distance: it arrives nearer at a grazing angle and at a lower render scale,
// which is why these are pixels and not metres. The measurements are in agents.md, "Why the windows flickered".
//
// AND ITS LIGHTS ARE HANDED OVER WITH RANGE: across the band before `windows_to` the wall gives up its lights by exactly
// the share the far lights take (town_handover.gdshaderinc, town_lights.gdshaderinc), and past it the wall gives none.
// Until 2026-09-15 they faded to FAR_GLOW's share of their average instead, and a far town was dim orange blocks. FAR_GLOW
// is now only what a wall averages to where its lights are too small to draw INSIDE that range, at a grazing angle.
//
// PLAIN and FINE are this file without and with `#define FINE` (building.gdshader and
// building_fine.gdshader), as the beacon is.
//
// INSTANCE_CUSTOM: x the roof (TownPlan.Roof), y a 0..1 hash of the building's seed, z its storeys.
//
// AND ONLY y IS READ. `x` and `z` are handed over by `TownView.building_custom` and this file has never looked at
// either: every roof kind draws the same flat `roof_colour` on any upward face, so FLAT, PLANT, PITCHED and SETBACK are
// the same picture. That is WP4, the building roof dressing, which `2a733e2b` said was not in it and which has not
// landed since.
//
// THIS COMMENT USED TO STOP AT THE LINE ABOVE, and that is how the absence stayed invisible for as long as it did: it
// reads as a description of what the shader does, so nobody checked. `lane/buildings` found on 2026-09-17 that
// `TownPlan.Roof.PITCHED` was unreachable -- the gate was 14.00 m and the narrowest building in the game is 14.02 m --
// fixed the gate, watched the counts change from "37 flat" to "12 flat, 25 pitched", and got back a village that was
// pixel-for-pixel the same town. A DECLARED INPUT THAT NOTHING READS IS WORSE THAN NO INPUT, because everything
// upstream of it goes on being maintained as though it mattered.
#include "res://world/shaders/eye.gdshaderinc"
#include "res://world/shaders/town_handover.gdshaderinc"

uniform float storey = 3.6;
uniform float bay = 3.2;
uniform float window_tall = 0.45;
uniform float window_wide = 0.55;
uniform float windows_to = 1400.0;
// The least pixels a pane's smaller side spans before it is drawn as a pane: TownTuning.WINDOW_PIXELS_LEAST.
uniform float window_pixels_least = 2.0;
// The least pixels a light's smaller side spans before its grid is made coarser: TownTuning.LIGHT_PIXELS_LEAST.
uniform float light_pixels_least = 3.0;
uniform vec3 glass : source_color = vec3(0.10, 0.13, 0.17);
uniform vec3 roof_colour : source_color = vec3(0.29, 0.29, 0.30);
uniform vec3 concrete : source_color = vec3(0.56, 0.55, 0.52);
uniform vec3 brick : source_color = vec3(0.46, 0.33, 0.27);

// LIT WINDOWS, which are the time of day's: the share of windows with a light on (0 by day) and how bright
// each is. Set once per change by TownView.light_windows, never per frame. WHICH window is lit is a hash of
// the window's own bay and storey, the face it is on and the building's seed -- the same record the box
// came from -- so the same windows are lit on every frame and in both eyes.
uniform float windows_lit = 0.0;
uniform float window_glow = 0.0;
// The far glow against the arithmetic average: TownTuning.FAR_GLOW, and why.
uniform float far_glow = 0.3;
#ifdef FINE
uniform vec3 window_warm : source_color = vec3(1.0, 0.70, 0.36);
uniform vec3 window_cool : source_color = vec3(0.78, 0.86, 1.0);
uniform float window_cool_share = 0.25;
uniform float window_light_least = 0.45;
#else
uniform vec3 window_light : source_color = vec3(1.0, 0.76, 0.42);
#endif

// How many times the lit grid may be made coarser: each doubles a light's size, so five is 32 windows a side, far past
// what `windows_to` lets a light be drawn at.
const float LIGHT_LEVELS = 5.0;

varying vec3 world_pos;
// Metres along the face, metres up from the ground, and how much the face points up (1 on a roof).
varying vec3 facade;
// FLAT, AND IT MUST STAY FLAT, like `face` below: both feed `window_hash`, which multiplies a sine by 43758, and a
// constant interpolated across a face comes back off by one part in ten million, pixel to pixel and moving with the
// view. As smooth varyings they made the pixels of one near window disagree about whether it was lit, and change
// their minds as the head moved: the flicker of 2026-09-13, 1217 toggles a frame down the street at night, 153 flat.
varying flat float shade_hash;
// Which of the four walls this is, as a number: two opposite walls share their `along` coordinates, and
// without this they would light the same windows mirrored.
varying flat float face;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	vec3 metres = VERTEX * size;
	vec3 n = abs(NORMAL);
	// ALONG THE FACE is the horizontal axis the face does not point down. BoxMesh gives every face its
	// own four vertices, so this is constant across a face and interpolates cleanly.
	float along = n.x > n.z ? metres.z : metres.x;
	facade = vec3(along, metres.y + size.y * 0.5, n.y);
	shade_hash = INSTANCE_CUSTOM.y;
	face = NORMAL.x * 1.0 + NORMAL.z * 3.0;
}

// A 0..1 hash of a window: its bay and storey, its wall and its building. Small inputs (tens), so the
// sine hash keeps its precision on a mobile GPU.
float window_hash(vec2 cell, float salt) {
	return fract(sin(dot(vec3(cell, face + salt), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// HOW MUCH OF THIS PIXEL IS WINDOW, in a grid of cells `cell` with `per_pixel` of a cell to a pixel: each edge ramped
// over one pixel. Taken off the continuous cell coordinate's own derivative, never off `fract`'s, whose wrap at a cell's
// edge would read as a whole cell.
float window_cover(vec2 cell, vec2 per_pixel) {
	vec2 inside = clamp((vec2(window_wide, window_tall) * 0.5 - abs(fract(cell) - 0.5)) / per_pixel + 0.5, 0.0, 1.0);
	return inside.x * inside.y;
}

// THE LIGHT OF THE LIT GRID MADE `level` TIMES COARSER: 2^level windows a side to a cell, the same share of cells lit and
// each light the same share of its cell. Level 0 is the windows themselves, with the hash they always had.
//
// A LIT WINDOW IS FILTERED IN WHAT IS SEEN, NOT IN LIGHT. A window glows at `window_glow` (2.2 at night), far past the
// tonemapper's knee, so a pixel a fifth covered by one still showed nearly white. So a pixel `on` covered is given the
// light the tonemapper -- taken as x / (1 + x) -- shows at `on` times a whole window; a whole window keeps its glow.
vec3 lights_at(vec2 cell, vec2 per_pixel, float level) {
	float scale = pow(2.0, level);
	vec2 coarse = cell / scale;
	vec2 id = floor(coarse);
	float salt = shade_hash * 61.0 + level * 7.0;
	float on = step(window_hash(id, salt), windows_lit) * window_cover(coarse, per_pixel / scale);
	float glow = window_glow * on / (1.0 + window_glow * (1.0 - on));
#ifdef FINE
	// Varied warmth: a warm lamp or a cool screen, and brighter or dimmer, by a second hash of the window.
	float h3 = window_hash(id + vec2(17.0, 5.0), shade_hash * 29.0 + level * 7.0);
	vec3 each = mix(window_warm, window_cool, step(1.0 - window_cool_share, h3))
		* mix(window_light_least, 1.0, fract(h3 * 13.7));
	return each * glow;
#else
	return window_light * glow;
#endif
}

void fragment() {
	float h2 = fract(shade_hash * 7.13 + 0.31);
	vec3 wall = mix(concrete, brick, step(0.62, shade_hash)) * (0.82 + 0.30 * h2);
	float far = length(world_pos - EYE_POSITION_WORLD);
	float near = 1.0 - town_far_share(far, windows_to);
	float wall_not_roof = 1.0 - step(0.5, facade.z);
	vec2 cell = vec2(facade.x / bay, facade.y / storey);
	vec2 per_pixel = max(fwidth(cell), vec2(1e-5));
	// How many pixels a window's smaller side spans here.
	float pixels = min(window_wide / per_pixel.x, window_tall / per_pixel.y);
	float area = window_wide * window_tall;

	// THE PANES, faded to their tone where they are too small to draw.
	float panes = min(near, smoothstep(window_pixels_least * 0.5, window_pixels_least, pixels));
	float share = mix(area, window_cover(cell, per_pixel), panes);
	vec3 albedo = mix(wall, glass, share);
	albedo = mix(albedo, roof_colour * (0.9 + 0.2 * h2), step(0.5, facade.z));
	ALBEDO = albedo;
	ROUGHNESS = mix(0.9, 0.35, share * wall_not_roof);

	// THE LIGHTS ON, on the grid coarse enough to draw: `level` is how many doublings a window needs to span
	// `light_pixels_least`, and the two grids either side of it are cross-faded. Past the coarsest the facade glows at
	// FAR_GLOW's share of what its lit windows average to. And all of it by the share the far lights leave the wall.
	float level = clamp(log2(light_pixels_least / pixels), 0.0, LIGHT_LEVELS);
	float finer = floor(level);
	vec3 lights = mix(lights_at(cell, per_pixel, finer), lights_at(cell, per_pixel, finer + 1.0),
		smoothstep(0.0, 1.0, level - finer));
	float drawn = smoothstep(light_pixels_least * 0.5, light_pixels_least, pixels * pow(2.0, LIGHT_LEVELS));
#ifdef FINE
	vec3 average = mix(window_warm, window_cool, window_cool_share) * (window_light_least + 1.0) * 0.5;
#else
	vec3 average = window_light;
#endif
	EMISSION = mix(average * window_glow * area * windows_lit * far_glow, lights, drawn) * near * wall_not_roof;
}
