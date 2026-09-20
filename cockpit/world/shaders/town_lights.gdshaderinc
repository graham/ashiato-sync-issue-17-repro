// A TOWN'S LIGHTS FROM FAR OFF: a point of light for every two windows by two on every wall, carrying the light those
// windows give, drawn where the wall has handed its lights over (town_handover.gdshaderinc).
//
// WHY POINTS. Past a few hundred metres a lit window is under a pixel, and the wall's shader can only average it, and a
// field of averaged lights is a glowing slab: the far town's "flat glowing orange blocks" of 2026-09-13, which FAR_GLOW
// dimmed and did not cure. Lights seen from far off are points with dark wall between. Asked for on 2026-09-15: "I should
// be able to see the lights on a building from farther away".
//
// THE LIGHT IS KEPT, NOT THE SIZE. Each instance is a cluster's lit window area (INSTANCE_CUSTOM.x, metres of wall, times
// the window's share of its cell) at `window_glow`, turned from the eye by its wall's facing and dimmed by the fog. That
// light, in pixels, is spread over a tent at least `point_pixels` half-wide, so a point never shrinks under a pixel and
// shimmers between two eyes: a tent sampled at pixel centres sums to the same light wherever its middle falls. A point
// widened past its own size is dimmed by the area it gained.
//
// AND A POINT TOO FAINT TO SEE IS THINNED, NOT DIMMED. Once a point's peak would fall under `point_least`, it is drawn at
// `point_least` if a hash of it (INSTANCE_CUSTOM.z) is under the share that keeps the light the same on average, faded
// over `THIN_BAND` of the hash so none pops. So a far town is fewer points, each still bright enough to see, with dark
// between -- the light it gives is what its windows give, and never a glow.
//
// AND CROWDED POINTS ARE GATHERED. Points closer than `point_spacing` pixels run together into a lit maze -- at 2 km, a
// cluster every 2.7 px drew each tower as a glowing block, FAR_GLOW's orange slabs by another road (2026-09-15). So only
// the share of them that would stand `point_spacing` apart is kept, by the same hash, and each carries the light of those
// it stands for. A town going away is fewer and brighter points, which is also what lets one be seen at 15 km.
//
// DIMMED BY THE SCENE'S OWN FOG, NOT SKIPPED BY IT. The engine's fog on an additive quad adds the fog's colour over the
// whole quad -- a square round every point at dusk -- so this is fog_disabled and takes the transmission itself,
// exp(-fog_density * away), the engine's own exponential fog with the environment's own density, which the level hands
// over whenever it changes (TownView.show_fog). Added over a background the engine has already fogged, which is what light
// through haze is.
//
// PLACED THROUGH billboard.gdshaderinc: the centre from MODELVIEW_MATRIX, the quad back into the instance's own space, no
// skip_vertex_transform on a multimesh. Steady far out on the double build. No TIME and no FRAGCOORD: the same in both
// eyes, still in a still frame.
//
// INSTANCE: basis columns along the wall, up, and out of it; INSTANCE_CUSTOM x the cluster's wall area in square metres,
// y the hash that decides whether it is lit (under `windows_lit`), z the hash that thins it, w the hash of its colour.
//
// PLAIN and FINE are this file without and with `#define FINE`, as the building is.
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/town_handover.gdshaderinc"
#include "res://world/shaders/scene_fog.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"

// The time of day's, set with the buildings' by TownView.light_windows: the share of windows lit and each one's glow.
uniform float windows_lit = 0.0;
uniform float window_glow = 0.0;
// The window's share of its bay and storey, and the wall's handover distance: the same numbers the building is handed.
uniform float window_wide = 0.55;
uniform float window_tall = 0.45;
uniform float windows_to = 1400.0;
// The environment's fog density, as the level last handed it. See the top.
uniform float fog_density = 0.0;
// The least half-width of a point, in pixels: TownTuning.FAR_LIGHT_PIXELS.
uniform float point_pixels = 1.5;
// The faintest peak a point is drawn at before it is thinned instead: TownTuning.FAR_LIGHT_LEAST.
uniform float point_least = 0.03;
// The fewest pixels between two points before they are gathered: TownTuning.FAR_LIGHT_SPACING.
uniform float point_spacing = 4.0;
#ifdef FINE
uniform vec3 window_warm : source_color = vec3(1.0, 0.70, 0.36);
uniform vec3 window_cool : source_color = vec3(0.78, 0.86, 1.0);
uniform float window_cool_share = 0.25;
uniform float window_light_least = 0.45;
#else
uniform vec3 window_light : source_color = vec3(1.0, 0.76, 0.42);
#endif

// How much of its own share a point fades over as the share passes its hash, so none pops.
const float THIN_BAND = 0.05;

// Which corner of the quad this is, -1..1 each way: the tent is worked out from it.
varying vec2 corner;
// The point's colour at its peak: the same on all four corners.
varying flat vec3 peak_colour;

void vertex() {
	vec3 centre_view = MODELVIEW_MATRIX[3].xyz;
	float away = max(length(centre_view), 1.0);
	vec3 to_eye = -centre_view / away;
	// The wall's normal in view space, and its facing towards the eye: its projected area, and a wall turned away gives no
	// light, fading to nothing as it turns edge-on.
	vec3 out_view = normalize(mat3(MODELVIEW_MATRIX)[2]);
	float facing = dot(out_view, to_eye);
	float lit = 1.0 - step(windows_lit, INSTANCE_CUSTOM.y);
	float carried = town_far_share(away, windows_to) * lit * step(0.0, facing);
	// METRES A PIXEL at this distance, off the projection and the viewport this eye is drawn into. ITS SIZE, NOT ITS SIGN:
	// Godot's RenderingDevice renderers flip Y inside the projection, so PROJECTION_MATRIX[1][1] is negative. Taken as it
	// came, every point's pixel spacing was negative, gathering clamped it to nothing and no far light drew at all -- while
	// the brightness, which squares it, looked right (2026-09-15).
	float metres_per_pixel = away * 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	float light_area = INSTANCE_CUSTOM.x * window_wide * window_tall;
	// The light, in luminance times square pixels: glow over the lit area, turned, through the fog.
	float light = window_glow * light_area * max(facing, 0.0) * scene_fog_transmission(away, fog_density)
		* (1.0 - mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz, mist_clock).a)
		/ (metres_per_pixel * metres_per_pixel);
	float half_pixels = max(0.5 * sqrt(light_area) / metres_per_pixel, point_pixels);
	// A separable tent half_pixels wide holds half_pixels squared times its peak.
	float peak = light / (half_pixels * half_pixels);
	// GATHERED: the share that stands `point_spacing` apart, each carrying the others' light; then THINNED where even that is
	// under `point_least`. One hash decides both, faded over a band proportional to the share, so the light kept on average
	// is the light given.
	float gathered = pow(clamp(sqrt(INSTANCE_CUSTOM.x) / metres_per_pixel / point_spacing, 0.0, 1.0), 2.0);
	float strong = peak / max(gathered, 1e-6);
	float share = gathered * min(strong / point_least, 1.0);
	float kept = clamp((share - INSTANCE_CUSTOM.z) / (THIN_BAND * share + 1e-6) + 0.5, 0.0, 1.0);
	peak = max(strong, point_least) * kept * carried;
#ifdef FINE
	float h = INSTANCE_CUSTOM.w;
	vec3 tint = mix(window_warm, window_cool, step(1.0 - window_cool_share, h))
		* mix(window_light_least, 1.0, fract(h * 13.7));
#else
	vec3 tint = window_light;
#endif
	peak_colour = tint * peak;
	// A point with nothing to give collapses to its centre and costs no pixels.
	float radius = half_pixels * metres_per_pixel * step(1e-5, peak);
	corner = VERTEX.xy;
	// STOOD OFF ITS OWN WALL BY HALF AGAIN ITS RADIUS, ALONG THE WALL'S NORMAL. The quad faces the eye, so on a wall seen at an
	// angle its corners lean into the wall by up to its radius times the root of two. Pulled towards the eye by its radius
	// instead, every point in front of a face lost the depth test to it and only those reaching past a building's edge were
	// drawn (2026-09-15); pulled a share of the range along the ray, faces filled, but a nearer block within that share
	// could not hide it. Along the normal it clears its own wall at any angle, and stands a few metres out -- 3.6 m at 2 km,
	// 27 m at 15 km -- where the nearest other building is an alley's 6 m away and, far off, a sub-pixel matter.
	vec3 offset_view = out_view * (radius * 1.5) + vec3(corner * radius, 0.0);
	VERTEX = BILLBOARD_LOCAL_FROM_VIEW(offset_view);
}

void fragment() {
	vec2 tent = max(1.0 - abs(corner), vec2(0.0));
	ALBEDO = peak_colour * tent.x * tent.y;
}
