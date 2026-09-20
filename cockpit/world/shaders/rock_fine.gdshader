// ROCK AND CONCRETE, ON THE FINE FINISH: the same boxes, lit as though they were not boxes.
//
// The mountains are axis-aligned boxes and must stay boxes -- every one of them is also a piece
// of the simulation's collision, and scenery drawn in a different shape from the thing you hit
// looks exactly like a networking fault. So nothing here moves a vertex. What reads as a box is
// not the silhouette at the distances mountains are seen from, it is the LIGHTING: eight faces,
// each one flat, each one lit evenly, with a knife edge between. So the fine finish attacks that:
//
//   THE SLOPE. Everything PLAIN does (rock.gdshader, rock_slope.gdshaderinc): each step lit partly as the peak's
//   slope, dark inner corners, scree, scrub and snow by how far under the slope the rock lies.
//
//   BEVELLED LIGHT AT THE EDGES. The normal is bent towards the edge it is nearest over the last
//   few metres of every face, so a ridge catches the light and rolls off it rather than switching
//   from lit to dark in one pixel. Measured from the box's own size, read off the instance scale.
//   ONLY THE LIGHT ROLLS: the outline is still the steps. Not rounded; nothing here can make it rounded.
//
//   RELIEF. Knobs and hollows a few metres tall, lit, from `value_noise_d` -- the slope comes
//   out of the same four hashes as the value.
//
//   LEDGES. A dark line under every bedding plane on a wall, which is the shadow a real ledge
//   throws, and the one thing that makes horizontal banding read as strata rather than as paint.
//
//   STAINS. Dark streaks run down a wall from the ledge above it, long and narrow, strongest at the top where the
//   water leaves the tread. One value noise, stretched. Before (2026-09-13) a wall was an even grey block.
//
// Concrete is this shader told there is no moss, no snow and a sharp edge: a building is a box. It carries no peak,
// so none of the slope reaches it.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
#include "res://world/shaders/eye.gdshaderinc"

#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/terrain_relief.gdshaderinc"
#include "res://world/shaders/rock_slope.gdshaderinc"

uniform vec3 low_colour : source_color = vec3(0.22, 0.21, 0.20);
uniform vec3 high_colour : source_color = vec3(0.46, 0.44, 0.41);
uniform vec3 face_colour : source_color = vec3(0.34, 0.32, 0.30);
uniform float strata : hint_range(0.0, 0.4) = 0.10;
uniform float grain : hint_range(0.0, 1.0) = 0.55;
uniform float coarse_scale = 0.010;
uniform float fine_scale = 0.22;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform vec3 moss_colour : source_color = vec3(0.23, 0.29, 0.15);
uniform vec3 snow_colour : source_color = vec3(0.90, 0.92, 0.95);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.7;
uniform float snow_amount : hint_range(0.0, 1.0) = 1.0;
// The most an edge is rounded over, in metres.
uniform float bevel = 14.0;
// How many metres tall the knobs on a face are lit as being.
uniform float relief = 5.0;
// ---- RockTuning's, set by SceneryYard.draw_boxes ----
uniform vec4 slope_share = vec4(0.30, 0.80, 300.0, 3000.0);
uniform vec3 corner = vec3(0.25, 1.0, 0.55);
uniform vec3 scree_colour : source_color = vec3(0.47, 0.44, 0.39);
uniform vec2 scree = vec2(0.45, 0.65);
uniform vec2 scrub_height = vec2(160.0, 320.0);
uniform vec2 snow_height = vec2(400.0, 40.0);
uniform vec3 streak = vec3(0.22, 0.09, 0.006);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 local_pos;
varying vec3 half_size;
varying vec4 peak;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_pos = VERTEX;
	half_size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)) * 0.5;
	peak = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 n = abs(world_normal);
	bool top = n.y > max(n.x, n.z);
	bool facing_x = !top && n.x > n.z;
	// The projection, chosen rather than blended, exactly as the plain rock does -- and the two
	// directions lying in this face, which the relief and the bevel both need.
	vec2 flat_uv = top ? world_pos.xz : (facing_x ? world_pos.zy : world_pos.xy);
	vec3 along_u = top ? vec3(1.0, 0.0, 0.0) : (facing_x ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0));
	vec3 along_v = top ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);

	float dist = length(world_pos - EYE_POSITION_WORLD);
	float near = detail_fade(dist, 400.0, 2600.0);
	float mid = detail_fade(dist, 1500.0, 6000.0);

	// ---- the plain rock ----
	float shape = fbm3_wrapped(flat_uv * coarse_scale, LATTICE_PERIOD);
	float bands = sin(world_pos.y * strata * 6.28318 + shape * 5.0) * 0.5 + 0.5;
	float fine = near > 0.001 ? fbm2(tile(flat_uv, 256.0) * fine_scale) * near : 0.0;
	float height = clamp(world_pos.y * 0.0022 + shape * 0.5, 0.0, 1.0);
	vec3 albedo = mix(low_colour, high_colour, height);
	albedo = mix(albedo, face_colour, bands * 0.35);
	albedo *= 0.82 + 0.18 * n.y;
	albedo *= 0.86 + grain * 0.28 * fine;

	// ---- the slope ----
	vec4 slope = peak_slope(world_pos, peak, half_size.y * 2.0);
	bool on_a_peak = slope.w >= 0.0;
	float under = max(slope.w, 0.0);

	// ---- relief ----
	vec3 knobs = value_noise_d(tile(flat_uv, 1024.0) * 0.06);
	vec2 tilt = knobs.yz * 0.06 * relief * mid;
	vec3 normal = normalize(world_normal) - along_u * tilt.x - along_v * tilt.y;
	albedo *= mix(1.0, 0.85 + 0.25 * knobs.x, mid);

	// ---- ledges and stains, on walls ----
	if (!top) {
		float ledge = smoothstep(0.80, 0.97, bands);
		albedo *= 1.0 - 0.30 * ledge * mid;
		if (on_a_peak) {
			float run = value_noise(tile(vec2(dot(world_pos, along_u) * streak.y, world_pos.y * streak.z), 512.0));
			albedo *= 1.0 - streak.x * smoothstep(0.55, 0.85, run) * (1.0 - 0.6 * clamp(under, 0.0, 1.0)) * mid;
		}
	}

	// ---- rounded edges ----
	vec3 metres = local_pos * half_size * 2.0;
	float gap_u = dot(half_size, abs(along_u)) - abs(dot(metres, along_u));
	float gap_v = dot(half_size, abs(along_v)) - abs(dot(metres, along_v));
	float radius = min(bevel, 0.3 * min(dot(half_size, abs(along_u)), dot(half_size, abs(along_v))));
	if (radius > 0.01) {
		vec3 outward = gap_u < gap_v
			? along_u * sign(dot(metres, along_u))
			: along_v * sign(dot(metres, along_v));
		float roll = 1.0 - clamp(min(gap_u, gap_v) / radius, 0.0, 1.0);
		normal += outward * roll * roll * 1.4;
	}
	normal = normalize(normal);
	if (on_a_peak) {
		normal = normalize(mix(normal, slope.xyz,
			mix(slope_share.x, slope_share.y, smoothstep(slope_share.z, slope_share.w, dist))));
	}

	// ---- where it meets things ----
	albedo *= mix(0.62, 1.0, smoothstep(0.0, 30.0, world_pos.y));
	float dusting = fbm2(tile(world_pos.xz, 1024.0) * 0.03);
	float up = (top && world_normal.y > 0.0) ? 1.0 : 0.0;
	// A wall's top few metres hold snow as well as the flat above it.
	float rim = top ? 0.0 : 1.0 - clamp((half_size.y - metres.y) / 5.0, 0.0, 1.0);
	// Deepest in the sheltered inner corner, thinnest on the lip -- where the wind leaves it.
	float shelter = on_a_peak ? mix(0.55, 1.0, smoothstep(0.0, 0.8, under)) : 1.0;
	float snow = smoothstep(snow_height.x - snow_height.y, snow_height.x + snow_height.y,
		world_pos.y + (dusting - 0.5) * 120.0) * snow_amount * max(up * shelter, rim * 0.8);
	float moss = (1.0 - smoothstep(scrub_height.x, scrub_height.y, world_pos.y)) * moss_amount * up
		* smoothstep(0.35, 0.65, dusting) * (on_a_peak ? 1.0 - smoothstep(0.15, 0.6, under) : 1.0);
	if (on_a_peak) {
		float fallen = smoothstep(scree.x, 1.0, under) * scree.y * up;
		albedo = mix(albedo, scree_colour, fallen * (0.7 + 0.3 * dusting));
	}
	albedo = mix(albedo, moss_colour, moss);
	albedo = mix(albedo, snow_colour, snow);
	if (on_a_peak) {
		albedo *= mix(1.0, corner.z, smoothstep(corner.x, corner.y, under) * (1.0 - snow));
	}

	ALBEDO = albedo;
	ROUGHNESS = roughness_value - 0.10 * fine - 0.25 * snow;
	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	NORMAL_MAP = vec3(0.5 + (fine - 0.5) * 0.35 * near,
		0.5 + (bands - 0.5) * 0.25 * near, 1.0);
}
