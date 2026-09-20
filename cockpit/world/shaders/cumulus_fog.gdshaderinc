// A CUMULUS AS FOG: where the cloud is, how dense, and what colour -- the colour a mesh cloud in the same place is lit.
//
// THE SHAPE IS THE LUMPS. Each FogVolume carries its own cloud's twenty-four lumps, laid out by `LiftYard.cloud_lumps` --
// the same function the mesh clouds and tests/air.gd are fed by -- so the fog stands exactly where the lumps stood and
// sits on the zone's one base. The noise only eats into that envelope; it never puts a cloud where the lumps were not.
//
// WORLD SPACE, NEVER THE VOLUME'S OR THE CAMERA'S. The noise is read at WORLD_POSITION, so a camera sliding sideways
// sees the cloud stand still in the air.
//
// LIT AS THE MESH CLOUD IS, BY `cloud_light.gdshaderinc`, SO THE CROSSFADE IS ONE COLOUR. The fog's own light is its
// EMISSION: the same `cloud_light` the lumps use, from the same uniforms `LiftYard.cloud_light` works out of the time of
// day, with the normal of the densest lump at that point, so a fog cloud has the mesh cloud's sunlit side and dark base.
// ALBEDO is black, so the engine's sun and ambient add nothing on top.
//
// EMISSION IS A COLOUR, NOT A SUM ALONG THE PATH -- which is what the prototype's note said, and it was wrong. Measured
// (2026-09-14, FINE by day, albedo black): deep in a cloud, emission 0.5 read 217 of 255 at the committed density and
// 216 at three times it, and 0.25 read 172, so the engine weights emission by the density itself. What turned the
// prototype's bases olive was its colour -- the ground's light under the sun's in-scatter -- not an accumulation.
// REJECTED: the engine's sun and `volumetric_fog_ambient_inject` 0.5 (the prototype): day fog read (175, 184, 202) against
// the lumps' (195, 201, 212), evening (137, 112, 116) against (216, 178, 147), night (34, 42, 64) against (17, 21, 32),
// and the ambient drew a band across the horizon from inside. And the environment's `volumetric_fog_emission`: it lights
// only the environment's own fog, whose density is 0 here -- 183.4 against 183.2 with it off.

#include "res://world/shaders/air_noise.gdshaderinc"
#include "res://world/shaders/cloud_light.gdshaderinc"

// TWENTY-FOUR, as CloudTuning.LUMPS: the lumps' centres in the world, and their radii along the cloud's heading, up and across.
uniform vec4 lump_at[24];
uniform vec3 lump_radii[24];
// The cloud's heading as (cos, sin): every lump is stretched along it (`LiftYard.cloud_lumps`).
uniform vec2 heading = vec2(1.0, 0.0);
// THE EYE, written by CloudBank to a cloud with fog in it, and how much finer detail it gets near it.
uniform vec3 eye_at = vec3(0.0, -100000.0, 0.0);
uniform float near_detail = 0.35;
uniform vec2 near_reach = vec2(80.0, 320.0);
// How much of the erosion is billows.
uniform float billow_share = 0.45;
// The cloud's one base (the zone's top) and its thickness, in metres -- LiftYard's custom data.
uniform float base_y = 1500.0;
uniform float thickness = 600.0;

// THE CLOUD'S ENVELOPE, `LiftYard.cloud_envelope` -- the same one its lumps are lit through, so the fog's core and far side
// are as dim as the mesh cloud's.
uniform vec3 envelope_centre = vec3(0.0, 1800.0, 0.0);
uniform vec3 envelope_radii = vec3(500.0, 300.0, 500.0);

uniform float core_density = 0.04;
// How much of this cloud is fog now, 0 to 1: CloudBank's share, from the eye's distance to the cloud.
uniform float presence = 1.0;
uniform float erosion = 0.55;
uniform float noise_scale = 0.00625;
uniform float climb = 0.8;
uniform float base_soft = 25.0;
uniform float lump_soft = 0.35;
// THE LIGHT THE ENGINE LIGHTS A FROXEL WITH, per unit of albedo, so the albedo can be the colour divided by it: the sun's
// colour made linear times its energy (`CloudBank.engine_sun`, from DaylightTuning -- NOT `sun_light`, which makes colour
// and energy linear together and is a sixth of the moon at night), times `sun_scale`: the PI a directional light's energy
// is multiplied by (`light_data.energy *= Math::PI`, light_storage.cpp) times the Henyey-Greenstein phase at anisotropy 0,
// 1 / (4 * PI) (volumetric_fog_process.glsl), times the light's volumetric fog energy of 1. Godot 4.7.
uniform vec3 engine_sun = vec3(1.0);
uniform float sun_scale = 0.25;

// 0 outside every lump to 1 in the heart of one, cut off below the base, and `normal` the densest lump's surface normal
// there. Squared distances, so no square root but the one normal.
float cloud_shape(vec3 p, out vec3 normal) {
	float best = 0.0;
	normal = vec3(0.0, 1.0, 0.0);
	for (int i = 0; i < 24; i++) {
		vec3 radii = max(lump_radii[i], vec3(0.01));
		vec3 rel = p - lump_at[i].xyz;
		// INTO THE CLOUD'S OWN FRAME: along its heading, up, across.
		vec3 local = vec3(rel.x * heading.x + rel.z * heading.y, rel.y, rel.z * heading.x - rel.x * heading.y);
		vec3 d = local / radii;
		float here = 1.0 - smoothstep(lump_soft, 1.0, dot(d, d));
		if (here > best) {
			best = here;
			vec3 g = d / radii;
			normal = vec3(g.x * heading.x - g.z * heading.y, g.y, g.x * heading.y + g.z * heading.x);
		}
	}
	normal = normalize(normal + vec3(0.0, 1e-6, 0.0));
	return best * smoothstep(0.0, base_soft, p.y - base_y);
}

// BILLOWS: 1 at the middle of a cell of the noise to 0 at its edge, from the nearest of eight jittered points -- a cheap
// cell-distance noise that bulges rather than ripples, which is what eats a cumulus edge into cauliflower.
float billows(vec3 q) {
	vec3 cell = floor(q);
	vec3 f = fract(q);
	float nearest = 8.0;
	for (int x = 0; x < 2; x++) {
		for (int y = 0; y < 2; y++) {
			for (int z = 0; z < 2; z++) {
				vec3 o = vec3(float(x), float(y), float(z));
				vec3 point = o + vec3(hash31(cell + o), hash31(cell + o + 19.19), hash31(cell + o + 47.47));
				vec3 r = point - f;
				nearest = min(nearest, dot(r, r));
			}
		}
	}
	return 1.0 - clamp(sqrt(nearest), 0.0, 1.0);
}

// The shape eroded by noise `n` (0..1): a solid core, a lumpy rim.
float cloud_density(float shape, float n) {
	return clamp((shape - (1.0 - n) * erosion) / max(1.0 - erosion, 0.05), 0.0, 1.0);
}

// The colour a mesh cloud has here: `cloud_light` with the lump's normal, the rise through the cloud and the noise as its
// texture term. No lining: a fog shader is not told where the eye is.
vec3 cloud_colour(vec3 p, vec3 normal, float n) {
	float rise = clamp((p.y - base_y) / max(thickness, 1.0), 0.0, 1.0);
	return cloud_light(normal, normal, rise, thickness, (n - 0.5) * 0.25, 0.0,
		envelope_sun_depth(p, envelope_centre, envelope_radii), envelope_buried(p, envelope_centre, envelope_radii));
}
