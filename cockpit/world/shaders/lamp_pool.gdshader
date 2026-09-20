// A STREET LAMP'S POOL OF LIGHT ON THE STREET UNDER IT: a flat quad the lamp's own instance stands on the street, lit as a
// matt road is lit by a lamp overhead, and handed to the lamp's point with distance (lamp_pool.gdshaderinc).
//
// NO LIGHT IN THE ENGINE'S SENSE. An OmniLight3D a lamp on the island's streets is thousands of dynamic lights, which no
// headset's frame affords; a pool is what a street lamp does to the street, and a quad drawing it costs its pixels only.
//
// THE LIGHT IS THE LAMP'S. Under a lamp of `street_candela` straight down at height h, the road at r metres from its foot
// is lit with candela * h / (h^2 + r^2)^1.5 lux (a lamp whose intensity falls as the cube of the cosine), and a matt road of
// `road_reflectance` shows reflectance / pi of that as luminance; `light_per_candela` turns candela per square metre into
// what the town draws with, the same number every lamp and window is drawn by. It fades out over the last 30 % of
// `pool_reach` mounting heights, where the next lamp's pool has taken over.
//
// THE SAME INSTANCE AS THE LAMP AND ITS POLE: its origin is the lamp's head, its basis's y column is the mounting height, so
// the quad stands at local y = -1, on the street, lifted `pool_lift` off it and pulled towards the eye by a share of the
// distance so the street's own surface never wins the depth test far off. Placed through billboard.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/scene_fog.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
#include "res://world/shaders/lamp_pool.gdshaderinc"

uniform float lamps = 0.0;
uniform float fog_density = 0.0;
uniform float light_per_candela = 0.011;
uniform float street_candela = 6000.0;
uniform float road_reflectance = 0.08;
uniform float pool_reach = 2.5;
uniform float pool_to = 1500.0;
uniform float pool_lift = 0.03;
uniform float pool_pull = 0.0005;
// HOW MUCH BRIGHTER THAN ITS LUMINANCE A POOL IS DRAWN, for the eye adapted to the night: TownTuning.night_adaptation(),
// which says how it is worked out.
uniform float night_adaptation = 1.0;
uniform vec3 street_colour : source_color = vec3(1.0, 0.62, 0.26);

varying vec2 across;
varying flat float height;
varying flat float strength;

void vertex() {
	float h = max(length(MODEL_MATRIX[1].xyz), 1.0);
	height = h;
	across = VERTEX.xz * (pool_reach * h);
	vec3 centre_view = MODELVIEW_MATRIX[3].xyz;
	float away = max(length(centre_view), 1.0);
	strength = lamps * (1.0 - lamp_pool_far_share(away, pool_to)) * scene_fog_transmission(away, fog_density);
	// AND THE LOW MIST THE POOL LIES UNDER, sampled once a vertex: an additive pool drawn after the mist pass would shine through
	// it. The pool's place in the world from the eye and the view's rotation, never INV_VIEW_MATRIX.
	strength *= 1.0 - mist_along(EYE_POSITION_WORLD, EYE_POSITION_WORLD + transpose(mat3(VIEW_MATRIX)) * centre_view, mist_clock).a;
	vec3 offset_view = mat3(MODELVIEW_MATRIX) * vec3(across.x, -1.0 + pool_lift / h, across.y);
	offset_view -= normalize(centre_view + offset_view) * (away * pool_pull);
	// A pool with nothing to give collapses to its centre and costs no pixels.
	VERTEX = BILLBOARD_LOCAL_FROM_VIEW(offset_view * step(1e-5, strength));
}

void fragment() {
	float h2 = height * height;
	float r2 = dot(across, across);
	float lux = street_candela * height / pow(h2 + r2, 1.5);
	float edge = 1.0 - smoothstep(0.7, 1.0, sqrt(r2) / (pool_reach * height));
	ALBEDO = street_colour * (light_per_candela * road_reflectance * night_adaptation / PI * lux * edge * strength);
}
